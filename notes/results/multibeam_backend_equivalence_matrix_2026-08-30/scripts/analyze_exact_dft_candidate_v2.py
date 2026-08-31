#!/usr/bin/env python3
from pathlib import Path
import csv,json,numpy as np
ROOT=Path(__file__).resolve().parents[1]
CASES={'plane_2m_dark':2.0,'plane_4m_dark':4.0,'plane_4m_bright':4.0,'plane_7m_dark':7.0,'sphere_4m_bright':4.0,'cylinder_4m_bright':4.0}
def metric(a):
 x=np.asarray(a,dtype=np.float64); x=x[np.isfinite(x)];
 return {'count':int(x.size),'mae':float(np.mean(np.abs(x))) if x.size else None,'rmse':float(np.sqrt(np.mean(x*x))) if x.size else None,'max_abs':float(np.max(np.abs(x))) if x.size else None}
rows=[]; details={}
for case,expected in CASES.items():
 cpu_p=ROOT/'results'/case/'cpu'; old_p=ROOT/'results'/case/'wgpu'; new_p=ROOT/'exact_dft_candidate_v2/results'/case/'wgpu'
 cpu_s=json.loads((cpu_p/'capture_summary.json').read_text()); old_s=json.loads((old_p/'capture_summary.json').read_text()); new_s=json.loads((new_p/'capture_summary.json').read_text())
 cpu=np.load(cpu_p/'first_frame_arrays.npz'); new=np.load(new_p/'first_frame_arrays.npz')
 both=np.isfinite(cpu['raw_sonar']) & np.isfinite(new['raw_sonar'])
 diff=(new['raw_sonar'].astype(float)-cpu['raw_sonar'].astype(float))[both]
 def med(s,k): return float(np.median([r[k] for r in s['raw_frames']]))
 d={'expected_range_m':expected,'cpu_peak_range_median':med(cpu_s,'peak_range_m'),'old_wgpu_peak_range_median':med(old_s,'peak_range_m'),'exact_dft_wgpu_peak_range_median':med(new_s,'peak_range_m'),'cpu_peak_error_median':med(cpu_s,'peak_error_m'),'old_wgpu_peak_error_median':med(old_s,'peak_error_m'),'exact_dft_wgpu_peak_error_median':med(new_s,'peak_error_m'),'cpu_expected_bin_ranks':[r['expected_bin_rank'] for r in cpu_s['raw_frames']],'old_wgpu_expected_bin_ranks':[r['expected_bin_rank'] for r in old_s['raw_frames']],'exact_dft_wgpu_expected_bin_ranks':[r['expected_bin_rank'] for r in new_s['raw_frames']],'raw_exact_dft_first_frame_minus_cpu':metric(diff),'exact_dft_unique_raw_hashes':len({r['data_sha256'] for r in new_s['raw_frames']})}
 details[case]=d; rows.append({'case':case,**{k:v for k,v in d.items() if not isinstance(v,(list,dict))},'exact_dft_rank_max':max(d['exact_dft_wgpu_expected_bin_ranks'])})
verdict={'candidate':'existing patches/multibeam_wgpu_and_backend_fix.diff exact N-point DFT, rebuilt wgpu_vendor archive and relinked with deferred-backend candidate','case_count':len(CASES),'details':details,'scope':'Docker software-WGPU llvmpipe controlled scenes. Peak placement and CPU/WGPU arrays are compared, but stochastic frames are not seed/frameIndex aligned and this is not general acoustic accuracy.'}
out=ROOT/'exact_dft_candidate_v2'; (out/'summary.json').write_text(json.dumps(verdict,indent=2)+'\n')
with (out/'summary.csv').open('w',newline='') as f: w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
print(json.dumps(verdict,indent=2))
