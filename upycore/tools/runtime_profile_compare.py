#!/usr/bin/env python3
"""Compare saved baseline/candidate kernels; require explicit image-change opt-in."""
import argparse,json
from pathlib import Path

def compare(before,after,allow_image_change=False):
    for key in ['compiler_flags','micro_loops']:
        if before.get(key)!=after.get(key):raise ValueError(f'incompatible {key}')
    a={r['name']:r for r in before['rows']};b={r['name']:r for r in after['rows']}
    if a.keys()!=b.keys():raise ValueError('case sets differ')
    rows=[]
    for name,r in a.items():
        s=b[name]
        if r['flags']!=s['flags']:raise ValueError('accelerator configurations differ')
        if r['expected_result']!=s['expected_result'] or r['profiled']['result']!=s['profiled']['result']:raise ValueError('result checks differ')
        same=r['image_sha256']==s['image_sha256']
        if not same and not allow_image_change:raise ValueError('images differ; use --allow-image-change for labeled firmware comparisons')
        x=r['profiled']['cycles'];y=s['profiled']['cycles']
        rows.append({'name':name,'baseline_cycles':x,'candidate_cycles':y,'change_pct':100*(y/x-1),'same_image':same})
    return {'baseline_commit':before['commit'],'candidate_commit':after['commit'],'comparison':'same-image RTL' if all(r['same_image'] for r in rows) else 'image-changing firmware/design','rows':rows}

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('baseline',type=Path);ap.add_argument('candidate',type=Path)
    ap.add_argument('--out',type=Path,required=True);ap.add_argument('--allow-image-change',action='store_true');a=ap.parse_args()
    result=compare(json.loads(a.baseline.read_text()),json.loads(a.candidate.read_text()),a.allow_image_change)
    a.out.write_text(json.dumps(result,indent=2)+'\n')

if __name__=='__main__':main()
