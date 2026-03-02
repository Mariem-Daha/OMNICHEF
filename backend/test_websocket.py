
import asyncio
import websockets
import json
import base64

async def test_websocket():
    uri = "ws://localhost:8000/ws-echo"
    # uri = "ws://localhost:8000/api/voice/ws"
    print(f"Connecting to {uri}...")
    try:
        async with websockets.connect(uri, origin="http://localhost:8000") as websocket:
            print("Connected!")
            
            # Wait for connected message
            response = await websocket.recv()
            print(f"Received: {response}")
            
            # Send a ping
            await websocket.send(json.dumps({"type": "ping"}))
            print("Sent ping")
            
            response = await websocket.recv()
            print(f"Received: {response}")
            
            # Send dummy audio (silence)
            # 1 second of silence at 16kHz mono (32000 bytes)
            silence = bytes(32000)
            b64_audio = base64.b64encode(silence).decode('utf-8')
            
            await websocket.send(json.dumps({
                "type": "audio",
                "data": b64_audio
            }))
            print("Sent audio chunk")
            
            # Wait a bit
            await asyncio.sleep(2)
            print("Closing...")
            
    except websockets.exceptions.ConnectionClosedError as e:
        print(f"Connection closed error: {e.code} {e.reason}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(test_websocket())
