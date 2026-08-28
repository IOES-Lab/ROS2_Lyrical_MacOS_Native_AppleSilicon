#!/usr/bin/env python3
import json, math, sys
from pathlib import Path

import rclpy
from rclpy.node import Node
from dave_interfaces.srv import (
    GetOriginSphericalCoord, SetOriginSphericalCoord,
    TransformFromSphericalCoord, TransformToSphericalCoord,
)

A = 6378137.0
F = 1.0 / 298.257223563
E2 = F * (2.0 - F)


def geodetic_to_ecef(lat_deg, lon_deg, alt):
    lat, lon = map(math.radians, (lat_deg, lon_deg))
    sl, cl = math.sin(lat), math.cos(lat)
    so, co = math.sin(lon), math.cos(lon)
    n = A / math.sqrt(1.0 - E2 * sl * sl)
    return (
        (n + alt) * cl * co,
        (n + alt) * cl * so,
        (n * (1.0 - E2) + alt) * sl,
    )


def ecef_to_geodetic(x, y, z):
    lon = math.atan2(y, x)
    p = math.hypot(x, y)
    lat = math.atan2(z, p * (1.0 - E2))
    for _ in range(20):
        s = math.sin(lat)
        n = A / math.sqrt(1.0 - E2 * s * s)
        alt = p / max(math.cos(lat), 1e-15) - n
        new = math.atan2(z, p * (1.0 - E2 * n / (n + alt)))
        if abs(new - lat) < 1e-14:
            lat = new
            break
        lat = new
    s = math.sin(lat)
    n = A / math.sqrt(1.0 - E2 * s * s)
    if abs(math.cos(lat)) > 1e-12:
        alt = p / math.cos(lat) - n
    else:
        alt = abs(z) / max(abs(math.sin(lat)), 1e-15) - n * (1.0 - E2)
    return math.degrees(lat), math.degrees(lon), alt


def enu_to_ecef(e, n, u, origin):
    lat, lon, alt = origin
    p0 = geodetic_to_ecef(lat, lon, alt)
    la, lo = map(math.radians, (lat, lon))
    sl, cl, so, co = math.sin(la), math.cos(la), math.sin(lo), math.cos(lo)
    dx = -so * e - sl * co * n + cl * co * u
    dy =  co * e - sl * so * n + cl * so * u
    dz =            cl * n      + sl * u
    return tuple(a+b for a,b in zip(p0, (dx,dy,dz)))


def ecef_to_enu(xyz, origin):
    lat, lon, alt = origin
    p0 = geodetic_to_ecef(lat, lon, alt)
    dx,dy,dz = (a-b for a,b in zip(xyz,p0))
    la, lo = map(math.radians, (lat, lon))
    sl, cl, so, co = math.sin(la), math.cos(la), math.sin(lo), math.cos(lo)
    return (
        -so*dx + co*dy,
        -sl*co*dx - sl*so*dy + cl*dz,
         cl*co*dx + cl*so*dy + sl*dz,
    )


class V(Node):
    def __init__(self):
        super().__init__('independent_geodesy_validator')
        self.c_get=self.create_client(GetOriginSphericalCoord,'/gz/get_origin_spherical_coordinates')
        self.c_set=self.create_client(SetOriginSphericalCoord,'/gz/set_origin_spherical_coordinates')
        self.c_to=self.create_client(TransformToSphericalCoord,'/gz/transform_to_spherical_coordinates')
        self.c_from=self.create_client(TransformFromSphericalCoord,'/gz/transform_from_spherical_coordinates')
    def wait(self):
        for c in (self.c_get,self.c_set,self.c_to,self.c_from):
            if not c.wait_for_service(60): raise TimeoutError(c.srv_name)
    def call(self,c,r):
        f=c.call_async(r); rclpy.spin_until_future_complete(self,f,timeout_sec=60)
        if f.result() is None: raise TimeoutError(c.srv_name)
        return f.result()


def wrap_lon_error(a,b):
    return ((a-b+180.0)%360.0)-180.0


def main():
    out=Path(sys.argv[1]); out.mkdir(parents=True,exist_ok=True)
    cases=[
      {'name':'busan_wide','origin':(35.074823,129.084798,0.0),'points':[(0,0,0),(1000,2000,300),(-5000,2500,-100),(10000,-8000,10000)]},
      {'name':'southern_hemisphere','origin':(-45.0,170.0,50.0),'points':[(0,0,0),(2500,-3000,500),(-10000,10000,-150)]},
      {'name':'dateline_east','origin':(0.0,179.999,0.0),'points':[(500,0,0),(2000,100,10),(-3000,-200,100)]},
      {'name':'near_north_pole','origin':(89.9,30.0,10.0),'points':[(100,100,0),(1000,-1000,200),(-2000,500,-50)]},
    ]
    rclpy.init(); v=V(); rows=[]
    try:
      v.wait()
      g=v.call(v.c_get,GetOriginSphericalCoord.Request())
      initial=(float(g.latitude_deg),float(g.longitude_deg),float(g.altitude))
      for case in cases:
        o=case['origin']
        sr=SetOriginSphericalCoord.Request(); sr.latitude_deg=o[0]; sr.longitude_deg=o[1]; sr.altitude=o[2]
        sresp=v.call(v.c_set,sr)
        if not sresp.success: raise RuntimeError(f'set failed {case["name"]}')
        for xyz in case['points']:
          tr=TransformToSphericalCoord.Request()
          tr.input.x,tr.input.y,tr.input.z=map(float,xyz)
          tresp=v.call(v.c_to,tr)
          observed=(float(tresp.latitude_deg),float(tresp.longitude_deg),float(tresp.altitude))
          oracle=ecef_to_geodetic(*enu_to_ecef(*map(float,xyz),o))
          fr=TransformFromSphericalCoord.Request()
          fr.latitude_deg,fr.longitude_deg,fr.altitude=oracle
          fresp=v.call(v.c_from,fr)
          from_oracle=(float(fresp.output.x),float(fresp.output.y),float(fresp.output.z))
          enu_error=tuple(a-b for a,b in zip(from_oracle,xyz))
          rows.append({
            'case':case['name'],'origin':o,'input_enu_m':xyz,
            'plugin_geodetic':observed,'independent_wgs84_geodetic':oracle,
            'error':{
              'latitude_deg':observed[0]-oracle[0],
              'longitude_deg':wrap_lon_error(observed[1],oracle[1]),
              'altitude_m':observed[2]-oracle[2],
            },
            'plugin_from_independent_geodetic_enu_m':from_oracle,
            'from_error_m':enu_error,
          })
      sr=SetOriginSphericalCoord.Request(); sr.latitude_deg=initial[0]; sr.longitude_deg=initial[1]; sr.altitude=initial[2]
      restore=v.call(v.c_set,sr)
      max_lat=max(abs(x['error']['latitude_deg']) for x in rows)
      max_lon=max(abs(x['error']['longitude_deg']) for x in rows)
      max_alt=max(abs(x['error']['altitude_m']) for x in rows)
      max_enu=max(abs(y) for x in rows for y in x['from_error_m'])
      result={
        'oracle':'independent WGS-84 geodetic<->ECEF plus ECEF<->ENU implementation',
        'case_count':len(cases),'point_count':len(rows),
        'maximum_error':{'latitude_deg':max_lat,'longitude_deg':max_lon,'altitude_m':max_alt,'from_enu_axis_m':max_enu},
        'restore_success':bool(restore.success),'rows':rows,
        'scope':'Independent numerical comparison over wide ENU offsets, southern hemisphere, dateline crossing and near-pole origin; not a survey-grade certification.'
      }
      (out/'results.json').write_text(json.dumps(result,indent=2)+'\n')
      print(json.dumps(result['maximum_error'],indent=2))
    finally:
      v.destroy_node(); rclpy.shutdown()

if __name__=='__main__': main()
