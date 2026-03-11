import asyncio
import websockets

async def test():
    async with websockets.connect('ws://localhost:8000/api/voice/ws-test') as ws:
        msg = await ws.recv()
        print(msg)

asyncio.run(test())
