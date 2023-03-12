from flask import Flask, jsonify, request
import mido
import pyaudio
import wave

import tensorflow as tf
import tensorflow_hub as hub

from scipy.io import wavfile
import music21
import crepe
import logging
import math
import statistics

logger = logging.getLogger()
logger.setLevel(logging.ERROR)

app = Flask(__name__)

chunk = 1024
sample_format = pyaudio.paInt16
channels = 1
fs = 44100
seconds = 3
ip_file = "input.wav"
op_file = "output.mid"
record = 0

A4 = 440
C0 = A4 * pow(2, -4.75)
note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

def hz2offset(freq):
    if freq == 0: 
        return None
    h = round(12 * math.log2(freq / C0))
    return 12 * math.log2(freq / C0) - h

def quantize_predictions(group, ideal_offset):
    non_zero_values = [v for v in group if v != 0]
    zero_values_count = len(group) - len(non_zero_values)

    if zero_values_count > 0.8 * len(group):
        return 0.51 * len(non_zero_values), "Rest"
    else:
        h = round(statistics.mean([12 * math.log2(freq / C0) - ideal_offset for freq in non_zero_values]))
        octave = h // 12
        n = h % 12
        note = note_names[n] + str(octave)
        error = sum([abs(12 * math.log2(freq / C0) - ideal_offset - h)for freq in non_zero_values])
        return error, note


def get_quantization_and_error(pitch_outputs_and_rests, predictions_per_eighth,prediction_start_offset, ideal_offset):
    pitch_outputs_and_rests = [0] * prediction_start_offset + pitch_outputs_and_rests

    groups = [pitch_outputs_and_rests[i:i + predictions_per_eighth] for i in range(0, len(pitch_outputs_and_rests), predictions_per_eighth)]
    quantization_error = 0

    notes_and_rests = []
    for group in groups:
        error, note_or_rest = quantize_predictions(group, ideal_offset)
        quantization_error += error
        notes_and_rests.append(note_or_rest)

    return quantization_error, notes_and_rests

@app.route('/record')
def record_vocal():
    global p
    p = pyaudio.PyAudio()
    global record
    record = 1
    global frames
    frames = []
    global stream
    stream = p.open(format=sample_format,channels=channels,rate=fs,frames_per_buffer=chunk,input_device_index=None,input=True)
    for i in range(0, int(fs / chunk * 100)):
        if record==1:
            data = stream.read(chunk)
            frames.append(data)
    return jsonify({"message": "record over"})

@app.route('/stop')
def stop_vocal():
    global record
    record = 0
    stream.stop_stream()
    stream.close()
    p.terminate()
    wf = wave.open(ip_file, 'wb')
    wf.setnchannels(channels)
    wf.setsampwidth(p.get_sample_size(sample_format))
    wf.setframerate(fs)
    wf.writeframes(b''.join(frames))
    wf.close()
    return jsonify({"message": "stop over"})

@app.route('/', methods=['POST','GET'])
def hello_world():
    if request.method == 'POST':
        fileName = request.json["fileName"]
        sr, audio = wavfile.read(fileName)
    else:
        sr, audio = wavfile.read(ip_file)
    time, frequency, confidence, activation = crepe.predict(audio, sr, viterbi=True, step_size=35)
    indices = range(len(frequency))
    pitch_outputs_and_rests = [
        p if c >= 0 else 0
        for i, p, c in zip(indices, frequency, confidence)
    ]
    
    offsets = [hz2offset(p) for p in pitch_outputs_and_rests if p != 0]
    print("offsets: ", offsets)

    ideal_offset = statistics.mean(offsets)
    print("ideal offset: ", ideal_offset)

    best_error = float("inf")
    best_notes_and_rests = None
    best_predictions_per_note = None

    for predictions_per_note in range(20, 65, 1):
        for prediction_start_offset in range(predictions_per_note):
            error, notes_and_rests = get_quantization_and_error(pitch_outputs_and_rests, predictions_per_note,prediction_start_offset, ideal_offset)
            if error < best_error:      
                best_error = error
                best_notes_and_rests = notes_and_rests
                best_predictions_per_note = predictions_per_note
    while best_notes_and_rests[0] == 'Rest':
        best_notes_and_rests = best_notes_and_rests[1:]
    while best_notes_and_rests[-1] == 'Rest':
        best_notes_and_rests = best_notes_and_rests[:-1]

    sc = music21.stream.Score()
    bpm = 60 * 60 / best_predictions_per_note
    a = music21.tempo.MetronomeMark(number=bpm)
    sc.insert(0,a)

    for snote in best_notes_and_rests:   
        d = 'half'
        if snote == 'Rest':      
            sc.append(music21.note.Rest(type=d))
        else:
            sc.append(music21.note.Note(snote, type=d))

    print(best_notes_and_rests)
    fp = sc.write('midi', fp=op_file)
    return jsonify({"message": "api over","notes":best_notes_and_rests})

@app.route('/play')
def play_midi():
    port = mido.open_output()
    mid = mido.MidiFile('instr.mid')
    for msg in mid.play():
        port.send(msg)
    return jsonify({"message": "play over"})

if __name__ == '__main__':
    app.run(threaded=True)

