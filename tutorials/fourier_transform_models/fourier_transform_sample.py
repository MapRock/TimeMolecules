import numpy as np

# --------------------- SIGNAL SETUP ---------------------
N = 8                    # number of samples
fs = 1000.0              # sampling rate in Hz
t = np.arange(N) / fs    # time points

# Create a pure 250 Hz sine wave (exactly lands on bin k=2)
freq1 = 250.0
signal = np.sin(2 * np.pi * freq1 * t)

# --------------------- FFT ---------------------
X = np.fft.rfft(signal)          # real FFT → only 0 to Nyquist
freqs = np.fft.rfftfreq(N, d=1/fs)

# Extract the attributes of each frequency component
real_parts = np.real(X)
imag_parts = np.imag(X)
mags = np.abs(X)
phases_deg = np.degrees(np.angle(X))

# --------------------- PRINT METADATA & TABLE ---------------------
print("=== FFT-LEVEL METADATA ===")
print(f"Original length N          : {N}")
print(f"Sampling rate fs           : {fs} Hz")
print(f"Signal was real-valued     : True")
print(f"FFT output length          : {len(X)} complex values")
print(f"Frequency resolution       : {fs/N:.1f} Hz\n")

print("=== FREQUENCY COMPONENTS TABLE ===")
print("k | Frequency (Hz) | Real      | Imag      | Magnitude | Phase (°)")
print("-" * 68)
for k in range(len(freqs)):
    print(f"{k:1d} | {freqs[k]:10.1f}     | {real_parts[k]:9.4f} | {imag_parts[k]:9.4f} | {mags[k]:9.4f} | {phases_deg[k]:8.2f}")