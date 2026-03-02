"""
Audio Utilities for Gemini Live API
Handles PCM audio resampling, format conversion, and validation
Supports 16kHz (input from client) and 24kHz (output from Gemini)
"""

import numpy as np
import logging
from typing import Optional, Tuple
import audioop
import struct

logger = logging.getLogger(__name__)


class AudioUtils:
    """Audio processing utilities for real-time streaming"""
    
    # Standard sample rates
    SAMPLE_RATE_16K = 16000  # Client microphone input
    SAMPLE_RATE_24K = 24000  # Gemini Live API output
    
    # Audio format constants
    BYTES_PER_SAMPLE_16BIT = 2
    CHANNELS_MONO = 1
    
    @staticmethod
    def resample_pcm(
        audio_data: bytes,
        from_rate: int,
        to_rate: int,
        num_channels: int = 1
    ) -> bytes:
        """
        Resample PCM audio from one sample rate to another
        
        Args:
            audio_data: Raw PCM bytes (16-bit signed little-endian)
            from_rate: Source sample rate (e.g., 16000)
            to_rate: Target sample rate (e.g., 24000)
            num_channels: Number of audio channels (1 for mono, 2 for stereo)
            
        Returns:
            Resampled PCM bytes
        """
        if from_rate == to_rate:
            return audio_data
        
        try:
            # Use audioop for efficient resampling
            state = None
            resampled, state = audioop.ratecv(
                audio_data,
                AudioUtils.BYTES_PER_SAMPLE_16BIT,
                num_channels,
                from_rate,
                to_rate,
                state
            )
            return resampled
        except Exception as e:
            logger.error(f"Resampling failed: {e}")
            return audio_data
    
    @staticmethod
    def resample_16k_to_24k(audio_16k: bytes) -> bytes:
        """
        Convert 16kHz PCM to 24kHz PCM for Gemini Live API
        
        Args:
            audio_16k: PCM bytes at 16kHz
            
        Returns:
            PCM bytes at 24kHz
        """
        return AudioUtils.resample_pcm(
            audio_16k,
            AudioUtils.SAMPLE_RATE_16K,
            AudioUtils.SAMPLE_RATE_24K
        )
    
    @staticmethod
    def resample_24k_to_16k(audio_24k: bytes) -> bytes:
        """
        Convert 24kHz PCM to 16kHz PCM for client playback
        (Not typically needed - clients can play 24kHz directly)
        
        Args:
            audio_24k: PCM bytes at 24kHz
            
        Returns:
            PCM bytes at 16kHz
        """
        return AudioUtils.resample_pcm(
            audio_24k,
            AudioUtils.SAMPLE_RATE_24K,
            AudioUtils.SAMPLE_RATE_16K
        )
    
    @staticmethod
    def validate_pcm_chunk(audio_data: bytes, expected_rate: int = 16000) -> bool:
        """
        Validate PCM audio chunk
        
        Args:
            audio_data: Raw PCM bytes to validate
            expected_rate: Expected sample rate
            
        Returns:
            True if valid, False otherwise
        """
        if not audio_data:
            return False
        
        # Check minimum size (at least 10ms of audio)
        min_bytes = int(expected_rate * 0.01 * AudioUtils.BYTES_PER_SAMPLE_16BIT)
        if len(audio_data) < min_bytes:
            return False
        
        # Check if length is multiple of sample size
        if len(audio_data) % AudioUtils.BYTES_PER_SAMPLE_16BIT != 0:
            logger.warning(f"Invalid PCM chunk size: {len(audio_data)} bytes")
            return False
        
        return True
    
    @staticmethod
    def calculate_audio_duration(audio_data: bytes, sample_rate: int) -> float:
        """
        Calculate duration of PCM audio in seconds
        
        Args:
            audio_data: Raw PCM bytes
            sample_rate: Sample rate (16000 or 24000)
            
        Returns:
            Duration in seconds
        """
        num_samples = len(audio_data) // AudioUtils.BYTES_PER_SAMPLE_16BIT
        return num_samples / sample_rate
    
    @staticmethod
    def normalize_audio_level(audio_data: bytes, target_rms: float = 0.3) -> bytes:
        """
        Normalize audio to target RMS level (optional preprocessing)
        
        Args:
            audio_data: Raw PCM bytes
            target_rms: Target RMS level (0.0 to 1.0)
            
        Returns:
            Normalized PCM bytes
        """
        try:
            # Convert bytes to int16 array
            audio_array = np.frombuffer(audio_data, dtype=np.int16)
            
            # Calculate current RMS
            current_rms = np.sqrt(np.mean(audio_array.astype(float) ** 2))
            
            if current_rms < 1.0:  # Avoid division by zero
                return audio_data
            
            # Calculate scaling factor
            target_rms_int16 = target_rms * 32767  # Max int16 value
            scale = target_rms_int16 / current_rms
            
            # Apply scaling with clipping
            normalized = np.clip(audio_array * scale, -32768, 32767).astype(np.int16)
            
            return normalized.tobytes()
        except Exception as e:
            logger.warning(f"Audio normalization failed: {e}")
            return audio_data
    
    @staticmethod
    def detect_silence(audio_data: bytes, threshold_db: float = -50.0) -> bool:
        """
        Detect if audio chunk is silence
        
        Args:
            audio_data: Raw PCM bytes
            threshold_db: Silence threshold in dB
            
        Returns:
            True if silence detected
        """
        try:
            # Convert bytes to int16 array
            audio_array = np.frombuffer(audio_data, dtype=np.int16)
            
            # Calculate RMS
            rms = np.sqrt(np.mean(audio_array.astype(float) ** 2))
            
            # Convert to dB
            if rms < 1.0:
                return True
            
            db = 20 * np.log10(rms / 32767)
            
            return db < threshold_db
        except Exception as e:
            logger.warning(f"Silence detection failed: {e}")
            return False
    
    @staticmethod
    def sanitize_audio_chunk(audio_data: bytes) -> bytes:
        """
        Sanitize audio chunk by ensuring proper alignment and removing invalid samples
        
        Args:
            audio_data: Raw PCM bytes
            
        Returns:
            Sanitized PCM bytes aligned to sample boundaries
        """
        if not audio_data:
            return audio_data
        
        # Ensure data is aligned to 16-bit samples (2 bytes)
        remainder = len(audio_data) % AudioUtils.BYTES_PER_SAMPLE_16BIT
        if remainder != 0:
            # Trim excess bytes to align to sample boundary
            audio_data = audio_data[:-remainder]
            logger.debug(f"Trimmed {remainder} bytes to align audio chunk")
        
        return audio_data
    
    @staticmethod
    def chunk_audio(
        audio_data: bytes,
        chunk_size_ms: int = 100,
        sample_rate: int = 16000
    ) -> list[bytes]:
        """
        Split audio into fixed-size chunks
        
        Args:
            audio_data: Raw PCM bytes
            chunk_size_ms: Chunk size in milliseconds
            sample_rate: Sample rate
            
        Returns:
            List of audio chunks
        """
        chunk_size_bytes = int(
            sample_rate * (chunk_size_ms / 1000.0) * AudioUtils.BYTES_PER_SAMPLE_16BIT
        )
        
        chunks = []
        for i in range(0, len(audio_data), chunk_size_bytes):
            chunk = audio_data[i:i + chunk_size_bytes]
            if len(chunk) == chunk_size_bytes:
                chunks.append(chunk)
        
        return chunks
    
    @staticmethod
    def convert_to_base64_data_url(audio_data: bytes, mime_type: str = "audio/pcm") -> str:
        """
        Convert PCM bytes to base64 data URL for web clients
        
        Args:
            audio_data: Raw PCM bytes
            mime_type: MIME type for the data URL
            
        Returns:
            Base64-encoded data URL
        """
        import base64
        b64_audio = base64.b64encode(audio_data).decode('utf-8')
        return f"data:{mime_type};base64,{b64_audio}"
    
    @staticmethod
    def apply_noise_reduction(audio_data: bytes, noise_profile: Optional[bytes] = None) -> bytes:
        """
        Apply simple noise reduction using spectral subtraction

        Args:
            audio_data: Raw PCM bytes
            noise_profile: Optional noise profile for subtraction

        Returns:
            Noise-reduced PCM bytes
        """
        try:
            # Convert bytes to int16 array
            audio_array = np.frombuffer(audio_data, dtype=np.int16).astype(np.float32)

            # Simple high-pass filter to remove low-frequency noise
            # This removes DC offset and rumble without complex FFT operations
            if len(audio_array) > 2:
                # Apply simple first-order high-pass filter
                alpha = 0.95  # Filter coefficient
                filtered = np.zeros_like(audio_array)
                filtered[0] = audio_array[0]

                for i in range(1, len(audio_array)):
                    filtered[i] = alpha * (filtered[i-1] + audio_array[i] - audio_array[i-1])

                # Convert back to int16 with clipping
                result = np.clip(filtered, -32768, 32767).astype(np.int16)
                return result.tobytes()

            return audio_data

        except Exception as e:
            logger.warning(f"Noise reduction failed: {e}")
            return audio_data

    @staticmethod
    def apply_automatic_gain_control(audio_data: bytes, target_level: float = 0.5) -> bytes:
        """
        Apply automatic gain control (AGC) to normalize volume

        Args:
            audio_data: Raw PCM bytes
            target_level: Target peak level (0.0 to 1.0)

        Returns:
            Volume-normalized PCM bytes
        """
        try:
            # Convert bytes to int16 array
            audio_array = np.frombuffer(audio_data, dtype=np.int16).astype(np.float32)

            # Find peak value
            peak = np.max(np.abs(audio_array))

            if peak < 100:  # Too quiet, likely noise
                return audio_data

            # Calculate gain to reach target level
            target_peak = target_level * 32767
            gain = target_peak / peak

            # Limit gain to prevent over-amplification
            gain = min(gain, 4.0)

            # Apply gain with soft limiting
            amplified = audio_array * gain
            result = np.clip(amplified, -32768, 32767).astype(np.int16)

            return result.tobytes()

        except Exception as e:
            logger.warning(f"AGC failed: {e}")
            return audio_data

    @staticmethod
    def enhance_audio(audio_data: bytes, apply_agc: bool = True, apply_nr: bool = False) -> bytes:
        """
        Apply audio enhancements for better speech quality

        Args:
            audio_data: Raw PCM bytes
            apply_agc: Apply automatic gain control
            apply_nr: Apply noise reduction

        Returns:
            Enhanced PCM bytes
        """
        result = audio_data

        if apply_nr:
            result = AudioUtils.apply_noise_reduction(result)

        if apply_agc:
            result = AudioUtils.apply_automatic_gain_control(result)

        return result

    @staticmethod
    def get_audio_info(audio_data: bytes, sample_rate: int) -> dict:
        """
        Get detailed info about audio data

        Args:
            audio_data: Raw PCM bytes
            sample_rate: Sample rate

        Returns:
            Dictionary with audio information
        """
        duration = AudioUtils.calculate_audio_duration(audio_data, sample_rate)
        num_samples = len(audio_data) // AudioUtils.BYTES_PER_SAMPLE_16BIT

        return {
            "size_bytes": len(audio_data),
            "sample_rate": sample_rate,
            "num_samples": num_samples,
            "duration_seconds": round(duration, 2),
            "duration_ms": round(duration * 1000, 0),
            "channels": AudioUtils.CHANNELS_MONO,
            "bits_per_sample": AudioUtils.BYTES_PER_SAMPLE_16BIT * 8,
            "is_valid": AudioUtils.validate_pcm_chunk(audio_data, sample_rate)
        }
