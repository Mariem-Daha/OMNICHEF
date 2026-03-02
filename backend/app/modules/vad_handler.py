"""
Voice Activity Detection (VAD) Handler
Provides real-time voice activity detection for natural turn-taking
"""

import numpy as np
from typing import Optional, Tuple
import logging

logger = logging.getLogger(__name__)


class VADHandler:
    """
    Voice Activity Detection using energy-based and zero-crossing rate methods
    Optimized for low-latency real-time processing
    """

    def __init__(
        self,
        sample_rate: int = 16000,
        frame_duration_ms: int = 30,
        energy_threshold: float = 0.015,
        zcr_threshold: float = 0.3,
        speech_frames_threshold: int = 2,
        silence_frames_threshold: int = 4,
    ):
        """
        Initialize VAD handler

        Args:
            sample_rate: Audio sample rate in Hz
            frame_duration_ms: Frame duration in milliseconds
            energy_threshold: Energy threshold for speech detection (0.0-1.0)
            zcr_threshold: Zero-crossing rate threshold
            speech_frames_threshold: Consecutive speech frames to trigger speech start
            silence_frames_threshold: Consecutive silence frames to trigger speech end
        """
        self.sample_rate = sample_rate
        self.frame_duration_ms = frame_duration_ms
        self.frame_size = int(sample_rate * frame_duration_ms / 1000)

        # Adaptive thresholds
        self.energy_threshold = energy_threshold
        self.zcr_threshold = zcr_threshold

        # State tracking
        self.speech_frames_threshold = speech_frames_threshold
        self.silence_frames_threshold = silence_frames_threshold
        self.consecutive_speech_frames = 0
        self.consecutive_silence_frames = 0
        self.is_speaking = False

        # Background noise estimation
        self.noise_energy = 0.0
        self.noise_samples = []
        self.max_noise_samples = 50

        logger.info(
            f"VAD initialized: {sample_rate}Hz, {frame_duration_ms}ms frames, "
            f"energy={energy_threshold}, zcr={zcr_threshold}"
        )

    def process_frame(self, audio_bytes: bytes) -> Tuple[bool, dict]:
        """
        Process a single audio frame and detect voice activity

        Args:
            audio_bytes: Raw PCM audio bytes (16-bit)

        Returns:
            Tuple of (is_speech, metrics) where metrics contains:
            - energy: Frame energy (0.0-1.0)
            - zcr: Zero-crossing rate
            - is_speaking: Current speech state
            - speech_confidence: Confidence score (0.0-1.0)
        """
        try:
            # Convert bytes to numpy array (int16 PCM)
            audio_data = np.frombuffer(audio_bytes, dtype=np.int16)

            if len(audio_data) == 0:
                return False, {"energy": 0.0, "zcr": 0.0, "is_speaking": False, "speech_confidence": 0.0}

            # Normalize to [-1.0, 1.0]
            normalized = audio_data.astype(np.float32) / 32768.0

            # Calculate features
            energy = self._calculate_energy(normalized)
            zcr = self._calculate_zcr(normalized)

            # Update background noise estimation
            self._update_noise_estimate(energy)

            # Adaptive threshold based on background noise
            adaptive_threshold = max(self.energy_threshold, self.noise_energy * 2.5)

            # Speech detection — energy only.
            # ZCR threshold (0.3) is unreliable across microphone models and
            # recording setups; requiring it caused VAD to never fire on many devices.
            is_speech_frame = energy > adaptive_threshold

            # State machine for speech detection
            if is_speech_frame:
                self.consecutive_speech_frames += 1
                self.consecutive_silence_frames = 0

                if self.consecutive_speech_frames >= self.speech_frames_threshold:
                    if not self.is_speaking:
                        logger.debug(f"Speech started (energy={energy:.4f}, zcr={zcr:.4f})")
                    self.is_speaking = True
            else:
                self.consecutive_silence_frames += 1
                self.consecutive_speech_frames = 0

                if self.consecutive_silence_frames >= self.silence_frames_threshold:
                    if self.is_speaking:
                        logger.debug(f"Speech ended (silence frames={self.consecutive_silence_frames})")
                    self.is_speaking = False

            # Calculate confidence score
            confidence = self._calculate_confidence(energy, zcr, adaptive_threshold)

            metrics = {
                "energy": float(energy),
                "zcr": float(zcr),
                "is_speaking": self.is_speaking,
                "speech_confidence": confidence,
                "adaptive_threshold": adaptive_threshold,
                "noise_energy": self.noise_energy,
            }

            return self.is_speaking, metrics

        except Exception as e:
            logger.error(f"VAD processing error: {e}")
            return False, {"error": str(e)}

    def _calculate_energy(self, audio: np.ndarray) -> float:
        """Calculate short-term energy (RMS)"""
        if len(audio) == 0:
            return 0.0
        return float(np.sqrt(np.mean(audio ** 2)))

    def _calculate_zcr(self, audio: np.ndarray) -> float:
        """Calculate zero-crossing rate"""
        if len(audio) < 2:
            return 0.0
        signs = np.sign(audio)
        zero_crossings = np.sum(np.abs(np.diff(signs))) / (2.0 * len(audio))
        return float(zero_crossings)

    def _update_noise_estimate(self, energy: float):
        """Update background noise estimation"""
        # Only update during silence
        if not self.is_speaking and len(self.noise_samples) < self.max_noise_samples:
            self.noise_samples.append(energy)
            if len(self.noise_samples) >= 10:
                self.noise_energy = np.mean(self.noise_samples)

    def _calculate_confidence(self, energy: float, zcr: float, threshold: float) -> float:
        """Calculate speech confidence score (0.0-1.0)"""
        energy_score = min(energy / (threshold * 2), 1.0)
        zcr_score = min(zcr / self.zcr_threshold, 1.0)
        return float((energy_score + zcr_score) / 2.0)

    def reset(self):
        """Reset VAD state"""
        self.consecutive_speech_frames = 0
        self.consecutive_silence_frames = 0
        self.is_speaking = False
        self.noise_samples = []
        self.noise_energy = 0.0
        logger.debug("VAD state reset")

    def is_speech(self, audio_bytes: bytes, sample_rate: int = None) -> bool:
        """
        Simple interface for speech detection

        Args:
            audio_bytes: Raw PCM audio bytes
            sample_rate: Optional sample rate override

        Returns:
            True if speech is detected in the audio frame
        """
        is_speaking, metrics = self.process_frame(audio_bytes)
        return is_speaking

    def get_state(self) -> dict:
        """Get current VAD state"""
        return {
            "is_speaking": self.is_speaking,
            "consecutive_speech_frames": self.consecutive_speech_frames,
            "consecutive_silence_frames": self.consecutive_silence_frames,
            "noise_energy": self.noise_energy,
        }


class SilenceDetector:
    """
    Adaptive silence detector for automatic turn completion
    Uses intelligent thresholds based on conversation context
    """

    def __init__(
        self,
        silence_duration_ms: int = 1500,
        sample_rate: int = 16000,
        adaptive: bool = True,
    ):
        """
        Initialize adaptive silence detector

        Args:
            silence_duration_ms: Base duration of silence to trigger turn end (ms)
            sample_rate: Audio sample rate
            adaptive: Enable adaptive threshold adjustment
        """
        self.base_silence_duration_ms = silence_duration_ms
        self.current_silence_duration_ms = silence_duration_ms
        self.sample_rate = sample_rate
        self.silence_frames = 0
        self.adaptive = adaptive

        # Adaptive threshold state
        self.speech_energy_history = []
        self.turn_count = 0
        self.last_speech_duration_frames = 0
        self.current_speech_duration_frames = 0

        self._recalculate_required_frames()

        logger.info(f"SilenceDetector initialized: {silence_duration_ms}ms base threshold (adaptive={adaptive})")

    def _recalculate_required_frames(self):
        """Recalculate required silence frames based on current threshold"""
        self.required_silence_frames = int(
            (self.current_silence_duration_ms / 1000) * (self.sample_rate / 160)  # Assuming 10ms frames
        )

    def process(self, is_speech: bool, vad_metrics: dict) -> bool:
        """
        Process VAD result with adaptive silence detection

        Args:
            is_speech: Current speech detection result
            vad_metrics: VAD metrics dictionary

        Returns:
            True if prolonged silence detected (should end turn)
        """
        # Track speech duration
        if is_speech:
            self.current_speech_duration_frames += 1
            self.silence_frames = 0

            # Store speech energy for adaptive learning
            if self.adaptive and 'energy' in vad_metrics:
                self.speech_energy_history.append(vad_metrics['energy'])
                # Keep only last 100 samples
                if len(self.speech_energy_history) > 100:
                    self.speech_energy_history.pop(0)
        else:
            self.silence_frames += 1

            # Adaptive threshold: adjust based on speech patterns
            if self.adaptive and self.silence_frames == 1:  # Just transitioned to silence
                self._adapt_threshold()

            if self.silence_frames >= self.required_silence_frames:
                logger.debug(
                    f"Prolonged silence detected: {self.silence_frames} frames "
                    f"(threshold={self.current_silence_duration_ms}ms, adaptive={self.adaptive})"
                )
                # Store speech duration for next adaptation
                self.last_speech_duration_frames = self.current_speech_duration_frames
                self.current_speech_duration_frames = 0
                self.turn_count += 1
                return True

        return False

    def _adapt_threshold(self):
        """
        Intelligently adapt silence threshold based on conversation patterns

        Rules:
        - Short bursts (< 1s speech) → shorter silence (1.5s) - quick confirmations
        - Medium utterances (1-3s) → standard silence (2s) - normal conversation
        - Long statements (> 3s) → longer silence (2.5s) - thinking/explaining
        """
        if not self.adaptive or self.last_speech_duration_frames == 0:
            return

        # Calculate speech duration in seconds
        speech_duration_s = self.last_speech_duration_frames / (self.sample_rate / 160)

        # Adaptive logic
        if speech_duration_s < 1.0:
            # Quick responses - use shorter silence
            new_threshold = 1500  # 1.5s
        elif speech_duration_s < 3.0:
            # Normal conversation - standard threshold
            new_threshold = 2000  # 2.0s
        else:
            # Long utterances - user might be thinking, wait longer
            new_threshold = 2500  # 2.5s

        # Smooth transition (moving average)
        if self.current_silence_duration_ms != new_threshold:
            self.current_silence_duration_ms = int(
                0.7 * self.current_silence_duration_ms + 0.3 * new_threshold
            )
            self._recalculate_required_frames()
            logger.debug(
                f"Adapted silence threshold: {self.current_silence_duration_ms}ms "
                f"(speech duration: {speech_duration_s:.1f}s)"
            )

    def reset(self):
        """Reset silence detection state"""
        self.silence_frames = 0
        self.current_speech_duration_frames = 0

    def get_stats(self) -> dict:
        """Get silence detector statistics"""
        return {
            "base_threshold_ms": self.base_silence_duration_ms,
            "current_threshold_ms": self.current_silence_duration_ms,
            "adaptive": self.adaptive,
            "turn_count": self.turn_count,
            "silence_frames": self.silence_frames,
            "avg_speech_energy": np.mean(self.speech_energy_history) if self.speech_energy_history else 0.0
        }
