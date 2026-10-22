#!/usr/bin/env python3
"""Composes the Noor promo film from real app recordings.

Inputs (from scripts/demo/capture.mjs + scripts/promo/render_assets.mjs):
  build/promo/clips/<scene>.mp4   real screen recordings (780x1688 @30fps)
  build/promo/assets/*.png        background, phone frame, mask, captions, title cards
Output: docs/media/noor-promo.mp4 (1920x1080, 30fps, H.264) + a 720p preview gif.
"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
B = os.path.join(ROOT, '..', '..', 'build', 'promo')
OUT = os.path.join(ROOT, '..', '..', 'docs', 'media')
SCENES = json.load(open(os.path.join(ROOT, 'scenes.json')))
FPS = 30
W, H = 1920, 1080
SW, SH = 408, 884          # screen inside the frame
FW, FH = 448, 924          # frame
XF = 0.7                   # crossfade seconds

def run(cmd):
    print(' '.join(cmd[:6]), '...', flush=True)
    subprocess.run(cmd, check=True)

def ease(t0, dur, a, b):
    # ease-out cubic from a to b starting at t0 over dur seconds (ffmpeg expression)
    k = f"min(max((t-{t0})/{dur},0),1)"
    return f"({a}+({b}-{a})*(1-pow(1-{k},3)))"

def scene(i, s):
    out = os.path.join(B, f'scene_{i:02d}.mp4')
    d = s['duration']
    bg = os.path.join(B, 'assets', 'bg-light.png' if s.get('light_bg') else 'bg.png')
    inputs = ['-loop', '1', '-t', str(d), '-i', bg]
    fc = []
    # slow Ken-Burns drift on the background
    fc.append(f"[0:v]scale=2112:1188,zoompan=z='1.0+0.0006*on':x='(iw-iw/zoom)/2+on*0.25':y='(ih-ih/zoom)/2':d={int(d*FPS)}:s={W}x{H}:fps={FPS}[bg0]")
    last = 'bg0'
    idx = 1
    if s['type'] == 'title':
        inputs += ['-loop', '1', '-t', str(d), '-i', os.path.join(B, 'assets', s['asset'] + '.png')]
        fc.append(f"[{idx}:v]format=rgba,fade=t=in:st=0.15:d=0.8:alpha=1[t]")
        fc.append(f"[{last}][t]overlay=x=0:y='{ease(0.15, 1.0, 40, 0)}'[v]")
        last = 'v'
    else:
        phones = s['phones']
        n = len(phones)
        # phone x positions (RTL layout: caption on the right, phones on the left)
        if s.get('caption'):
            xs = [300] if n == 1 else [90, 570]
        else:
            xs = [W // 2 - FW // 2] if n == 1 else [W // 2 - FW - 30, W // 2 + 30]
        for j, ph in enumerate(phones):
            inputs += ['-t', str(d), '-i', os.path.join(B, 'clips', ph + '.mp4')]
            ci = idx; idx += 1
            inputs += ['-loop', '1', '-t', str(d), '-i', os.path.join(B, 'assets', 'mask.png')]
            mi = idx; idx += 1
            inputs += ['-loop', '1', '-t', str(d), '-i', os.path.join(B, 'assets', 'frame.png')]
            fi = idx; idx += 1
            delay = 0.2 + 0.18 * j
            fc.append(f"[{ci}:v]fps={FPS},scale={SW}:{SH}:flags=lanczos,format=rgba,tpad=stop_mode=clone:stop_duration={d}[c{j}]")
            fc.append(f"[{mi}:v]scale={SW}:{SH},format=gray[m{j}]")
            fc.append(f"[c{j}][m{j}]alphamerge[cm{j}]")
            fc.append(f"[{fi}:v]format=rgba[f{j}]")
            fc.append(f"[f{j}][cm{j}]overlay=20:20[ph{j}]")
            # soft shadow
            fc.append(f"[ph{j}]split[ph{j}a][ph{j}b]")
            fc.append(f"[ph{j}b]colorchannelmixer=rr=0:gg=0:bb=0:aa=0.55,boxblur=28:2[sh{j}]")
            x = xs[j]
            y0, y1 = H + 40, (H - FH) // 2
            fc.append(f"[{last}][sh{j}]overlay=x={x + 10}:y='{ease(delay, 1.1, y0 + 40, y1 + 34)}':shortest=1[s{j}]")
            fc.append(f"[s{j}][ph{j}a]overlay=x={x}:y='{ease(delay, 1.1, y0, y1)}':shortest=1[p{j}]")
            last = f'p{j}'
        if s.get('caption'):
            inputs += ['-loop', '1', '-t', str(d), '-i', os.path.join(B, 'assets', s['caption'] + '.png')]
            fc.append(f"[{idx}:v]format=rgba,fade=t=in:st=0.45:d=0.7:alpha=1[cap]")
            fc.append(f"[{last}][cap]overlay=x='{ease(0.45, 1.0, 1150, 1100)}':y=(H-h)/2[v]")
            last = 'v'
    fc.append(f"[{last}]format=yuv420p,trim=duration={d},setpts=PTS-STARTPTS[out]")
    run(['ffmpeg', '-y', '-loglevel', 'error', *inputs, '-filter_complex', ';'.join(fc), '-map', '[out]',
         '-r', str(FPS), '-c:v', 'libx264', '-preset', 'medium', '-crf', '16', out])
    return out, d

def main():
    os.makedirs(OUT, exist_ok=True)
    parts = [scene(i, s) for i, s in enumerate(SCENES)]
    # chain crossfades
    inputs = []
    for p, _ in parts:
        inputs += ['-i', p]
    fc = []
    acc = parts[0][1]
    last = '0:v'
    for k in range(1, len(parts)):
        off = acc - XF
        trans = SCENES[k].get('transition', 'fade')
        fc.append(f"[{last}][{k}:v]xfade=transition={trans}:duration={XF}:offset={off:.3f}[x{k}]")
        last = f'x{k}'
        acc += parts[k][1] - XF
    fc.append(f"[{last}]fade=t=in:st=0:d=0.6,fade=t=out:st={acc - 0.8:.3f}:d=0.8,format=yuv420p[v]")
    final = os.path.join(OUT, 'noor-promo.mp4')
    run(['ffmpeg', '-y', '-loglevel', 'error', *inputs, '-filter_complex', ';'.join(fc), '-map', '[v]',
         '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-movflags', '+faststart', '-r', str(FPS), final])
    # lightweight README preview
    pal = os.path.join(B, 'pal.png')
    run(['ffmpeg', '-y', '-loglevel', 'error', '-i', final, '-vf', 'fps=10,scale=640:-1:flags=lanczos,palettegen=stats_mode=diff', pal])
    run(['ffmpeg', '-y', '-loglevel', 'error', '-i', final, '-i', pal, '-lavfi',
         'fps=10,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5', os.path.join(OUT, 'noor-promo.gif')])
    print('promo duration %.1fs' % acc)

if __name__ == '__main__':
    sys.exit(main())
