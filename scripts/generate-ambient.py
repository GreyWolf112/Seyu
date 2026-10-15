"""Build 60-second loops from licensed field recordings, never synthetic noise.
Input: decoded 44100Hz mono PCM16 rain.wav, rocks.wav, forest.wav.
Example: python3 scripts/generate-ambient.py /tmp/zhiyu-field-recordings
Source URLs and attribution: docs/ambient-audio-sources.md.
"""
from pathlib import Path
import argparse, array, hashlib, json, math, sys, wave
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source_dir', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
out_dir = root / 'entry/src/main/resources/rawfile/ambient'
rate = 44100
length, overlap = rate * 60, rate * 2
report = {}
for name, source, offset in [('rain', 'rain', 15), ('ocean', 'rocks', 5), ('forest', 'forest', 5)]:
    input_path = args.source_dir / (source + '.wav')
    with wave.open(str(input_path), 'rb') as wav:
        assert (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) == (rate, 1, 2)
        wav.setpos(offset * rate)
        pcm = array.array('h', wav.readframes(length + overlap))
    if sys.byteorder != 'little': pcm.byteswap()
    if len(pcm) != length + overlap: raise ValueError(f'{source}: insufficient recording length')
    samples = [x / 32768 for x in pcm]
    # Rotate and join adjacent tails: last sample connects to head at overlap index.
    result = samples[overlap:length]
    for i in range(overlap):
        f = i / (overlap - 1)
        result.append(samples[length + i] * math.cos(f * math.pi / 2) + samples[i] * math.sin(f * math.pi / 2))
    dc = sum(result) / len(result)
    result = [x - dc for x in result]
    rms = math.sqrt(sum(x*x for x in result) / len(result))
    peak = max(abs(x) for x in result)
    gain = min(0.09 / max(rms, 1e-9), 0.8 / max(peak, 1e-9))
    encoded = array.array('h', (round(x * gain * 32767) for x in result))
    if sys.byteorder != 'little': encoded.byteswap()
    target = out_dir / (name + '.wav')
    with wave.open(str(target), 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(rate); wav.writeframes(encoded.tobytes())
    report[name] = {'source': source, 'offsetSeconds': offset, 'durationSeconds': 60,
        'sourceDecodedSha256': hashlib.sha256(input_path.read_bytes()).hexdigest(),
        'outputSha256': hashlib.sha256(target.read_bytes()).hexdigest(),
        'peak': round(peak * gain, 5), 'rms': round(rms * gain, 5)}
    print(name, report[name])
(root / 'docs/ambient-audio-build.json').write_text(json.dumps(report, indent=2) + '\n')
