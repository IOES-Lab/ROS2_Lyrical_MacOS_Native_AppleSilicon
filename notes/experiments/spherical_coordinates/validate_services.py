#!/usr/bin/env python3
"""Call every SphericalCoords service and preserve discriminating results."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import rclpy
from dave_interfaces.srv import (
    GetOriginSphericalCoord,
    SetOriginSphericalCoord,
    TransformFromSphericalCoord,
    TransformToSphericalCoord,
)
from rclpy.node import Node


SERVICES = {
    "get": (GetOriginSphericalCoord, "/gz/get_origin_spherical_coordinates"),
    "set": (SetOriginSphericalCoord, "/gz/set_origin_spherical_coordinates"),
    "to": (TransformToSphericalCoord, "/gz/transform_to_spherical_coordinates"),
    "from": (TransformFromSphericalCoord, "/gz/transform_from_spherical_coordinates"),
}


class Validator(Node):
    def __init__(self) -> None:
        super().__init__("spherical_coordinates_direct_validator")
        self.service_clients = {
            key: self.create_client(srv_type, name)
            for key, (srv_type, name) in SERVICES.items()
        }

    def wait(self) -> None:
        for key, client in self.service_clients.items():
            if not client.wait_for_service(timeout_sec=60.0):
                raise TimeoutError(f"service unavailable: {key}")

    def call(self, key: str, request):
        future = self.service_clients[key].call_async(request)
        rclpy.spin_until_future_complete(self, future, timeout_sec=60.0)
        if not future.done() or future.result() is None:
            raise TimeoutError(f"service did not answer: {key}")
        return future.result()


def spherical(response) -> dict:
    return {
        "latitude_deg": float(response.latitude_deg),
        "longitude_deg": float(response.longitude_deg),
        "altitude": float(response.altitude),
    }


def vector(vector_msg) -> dict:
    return {"x": float(vector_msg.x), "y": float(vector_msg.y), "z": float(vector_msg.z)}


def error(a: dict, b: dict) -> dict:
    return {key: a[key] - b[key] for key in ("x", "y", "z")}


def finite_map(values: dict) -> bool:
    return all(math.isfinite(value) for value in values.values())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("platform")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    rclpy.init()
    node = Validator()
    try:
        node.wait()

        initial = spherical(node.call("get", GetOriginSphericalCoord.Request()))

        set_request = SetOriginSphericalCoord.Request()
        set_request.latitude_deg = -24.71897669633431
        set_request.longitude_deg = -46.515625
        set_request.altitude = 100.0
        set_response = node.call("set", set_request)
        after_set = spherical(node.call("get", GetOriginSphericalCoord.Request()))

        round_trips = []
        for xyz in ((0.0, 0.0, 0.0), (100.0, 200.0, 3.0), (-250.0, 50.0, -20.0)):
            to_request = TransformToSphericalCoord.Request()
            to_request.input.x, to_request.input.y, to_request.input.z = xyz
            to_response = node.call("to", to_request)
            sc = spherical(to_response)

            from_request = TransformFromSphericalCoord.Request()
            from_request.latitude_deg = sc["latitude_deg"]
            from_request.longitude_deg = sc["longitude_deg"]
            from_request.altitude = sc["altitude"]
            from_response = node.call("from", from_request)
            returned = vector(from_response.output)
            requested = dict(zip(("x", "y", "z"), xyz))
            round_trips.append(
                {
                    "input_local": requested,
                    "spherical": sc,
                    "returned_local": returned,
                    "error_m": error(returned, requested),
                }
            )

        wiki_from_request = TransformFromSphericalCoord.Request()
        wiki_from_request.latitude_deg = -24.720782227452414
        wiki_from_request.longitude_deg = -46.51661335064305
        wiki_from_request.altitude = 103.00393470842391
        wiki_expected_to_local = vector(node.call("from", wiki_from_request).output)

        nan_to_request = TransformToSphericalCoord.Request()
        nan_to_request.input.x = float("nan")
        nan_to_response = spherical(node.call("to", nan_to_request))

        nan_from_request = TransformFromSphericalCoord.Request()
        nan_from_request.latitude_deg = float("nan")
        nan_from_request.longitude_deg = -46.515625
        nan_from_request.altitude = 100.0
        nan_from_response = vector(node.call("from", nan_from_request).output)

        invalid_set_request = SetOriginSphericalCoord.Request()
        invalid_set_request.latitude_deg = 100.0
        invalid_set_request.longitude_deg = 200.0
        invalid_set_request.altitude = 0.0
        invalid_set_response = node.call("set", invalid_set_request)
        after_invalid_set = spherical(node.call("get", GetOriginSphericalCoord.Request()))

        restore_request = SetOriginSphericalCoord.Request()
        restore_request.latitude_deg = initial["latitude_deg"]
        restore_request.longitude_deg = initial["longitude_deg"]
        restore_request.altitude = initial["altitude"]
        restore_response = node.call("set", restore_request)
        restored = spherical(node.call("get", GetOriginSphericalCoord.Request()))

        result = {
            "platform": args.platform,
            "services": {key: name for key, (_, name) in SERVICES.items()},
            "initial_origin": initial,
            "set_wiki_origin_success": bool(set_response.success),
            "origin_after_set": after_set,
            "round_trips": round_trips,
            "wiki_documented_spherical_for_local_100_200_3": {
                "latitude_deg": -24.720782227452414,
                "longitude_deg": -46.51661335064305,
                "altitude": 103.00393470842391,
            },
            "wiki_documented_spherical_converts_to_local": wiki_expected_to_local,
            "non_finite_input": {
                "to_spherical": nan_to_response,
                "to_spherical_all_finite": finite_map(nan_to_response),
                "from_spherical": nan_from_response,
                "from_spherical_all_finite": finite_map(nan_from_response),
            },
            "out_of_range_origin": {
                "request": {"latitude_deg": 100.0, "longitude_deg": 200.0, "altitude": 0.0},
                "service_success": bool(invalid_set_response.success),
                "reported_after_set": after_invalid_set,
            },
            "restore_success": bool(restore_response.success),
            "restored_origin": restored,
        }
        (args.output / "results.json").write_text(
            json.dumps(result, indent=2, allow_nan=True) + "\n"
        )
        print(json.dumps(result, indent=2, allow_nan=True))
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
