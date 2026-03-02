"""
Test multi-turn conversation with automatic VAD-based turn detection
"""
import asyncio
import websockets
import json
import base64
import numpy as np

async def simulate_speech(websocket, duration_ms=2000, silence_after_ms=2000):
    """
    Simulate speech followed by silence
    - Sends 2 seconds of "speech" (simulated audio with some noise)
    - Then 2 seconds of silence
    - Backend should auto-detect end-of-turn during silence
    """
    sample_rate = 16000
    chunk_duration_ms = 100  # 100ms chunks
    samples_per_chunk = int(sample_rate * chunk_duration_ms / 1000)

    # Calculate how many chunks
    speech_chunks = int(duration_ms / chunk_duration_ms)
    silence_chunks = int(silence_after_ms / chunk_duration_ms)

    print(f"\n--- Simulating speech for {duration_ms}ms followed by {silence_after_ms}ms silence ---")

    # Send speech chunks (simulated with random noise)
    for i in range(speech_chunks):
        # Generate simulated speech (random noise around -5000 to 5000)
        noise = np.random.randint(-5000, 5000, samples_per_chunk, dtype=np.int16)
        audio_bytes = noise.tobytes()
        audio_b64 = base64.b64encode(audio_bytes).decode('utf-8')

        await websocket.send(json.dumps({
            "type": "audio",
            "data": audio_b64
        }))
        await asyncio.sleep(chunk_duration_ms / 1000)

    print(f"  Sent {speech_chunks} speech chunks")

    # Send silence chunks (zeros)
    for i in range(silence_chunks):
        silence = np.zeros(samples_per_chunk, dtype=np.int16)
        audio_bytes = silence.tobytes()
        audio_b64 = base64.b64encode(audio_bytes).decode('utf-8')

        await websocket.send(json.dumps({
            "type": "audio",
            "data": audio_b64
        }))
        await asyncio.sleep(chunk_duration_ms / 1000)

    print(f"  Sent {silence_chunks} silence chunks")
    print("  Waiting for backend to detect end-of-turn...")

async def test_multiturn():
    uri = "ws://127.0.0.1:8000/api/voice/ws"
    print(f"Connecting to {uri}...")

    try:
        async with websockets.connect(uri, open_timeout=20) as websocket:
            print("SUCCESS: WebSocket connected!\n")

            # Wait for connected message
            response = await asyncio.wait_for(websocket.recv(), timeout=10.0)
            data = json.loads(response)
            print(f"Connected - Session: {data.get('session_id')}\n")

            # Create task to listen for responses
            async def listen_for_responses():
                turn = 0
                while True:
                    try:
                        msg = await websocket.recv()
                        data = json.loads(msg)
                        msg_type = data.get('type')

                        if msg_type == 'transcript':
                            print(f"  << Gemini: {data.get('text')}")
                        elif msg_type == 'turn_complete':
                            turn += 1
                            print(f"\n=== Turn {turn} Complete ===\n")
                        elif msg_type == 'audio':
                            print(f"  << Received audio chunk ({len(data.get('data', ''))} bytes)")
                        elif msg_type == 'function_executed':
                            print(f"  << Function: {data.get('function')}")

                    except Exception as e:
                        print(f"Listener error: {e}")
                        break

            listener_task = asyncio.create_task(listen_for_responses())

            # Simulate Turn 1
            print("=== TURN 1: Short utterance ===")
            await simulate_speech(websocket, duration_ms=800, silence_after_ms=2000)
            await asyncio.sleep(3)  # Wait for response

            # Simulate Turn 2
            print("\n=== TURN 2: Normal utterance ===")
            await simulate_speech(websocket, duration_ms=2000, silence_after_ms=2500)
            await asyncio.sleep(3)  # Wait for response

            # Simulate Turn 3
            print("\n=== TURN 3: Long utterance ===")
            await simulate_speech(websocket, duration_ms=4000, silence_after_ms=3000)
            await asyncio.sleep(5)  # Wait for response

            print("\n\nTest completed! Check if backend automatically detected 3 turn completions.")

            listener_task.cancel()

    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_multiturn())
