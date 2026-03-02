import asyncio
import websockets
import json

async def test_websocket():
    uri = "ws://127.0.0.1:8000/api/voice/ws"
    print(f"Connecting to {uri}...")

    try:
        async with websockets.connect(uri, open_timeout=20) as websocket:
            print("SUCCESS: WebSocket connected!")

            # Wait for connected message with timeout
            try:
                response = await asyncio.wait_for(websocket.recv(), timeout=20.0)
                print(f"SUCCESS: Received: {response}")
                data = json.loads(response)
                print(f"SUCCESS: Message type: {data.get('type')}")
                print(f"SUCCESS: Session ID: {data.get('session_id')}")
            except asyncio.TimeoutError:
                print("ERROR: Timeout waiting for connected message")

    except websockets.exceptions.WebSocketException as e:
        print(f"ERROR: WebSocket error: {e}")
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_websocket())
