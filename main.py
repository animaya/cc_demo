import asyncio
import json
import random
import time
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from typing import AsyncGenerator

app = FastAPI(title="Random Message Streaming Server")

# Pool of random messages to stream
RANDOM_MESSAGES = [
    "The quick brown fox jumps over the lazy dog",
    "Python is an amazing programming language",
    "FastAPI makes building APIs incredibly easy",
    "Streaming data in real-time is powerful",
    "uvicorn is a lightning-fast ASGI server",
    "Random messages can be quite entertaining",
    "Server-Sent Events enable real-time communication",
    "HTTP streaming opens up many possibilities",
    "This message was generated randomly",
    "Welcome to the random message stream!",
    "Did you know octopuses have three hearts?",
    "The mitochondria is the powerhouse of the cell",
    "Coffee is the fuel of programmers",
    "Code never lies, comments sometimes do",
    "There are only 10 types of people in the world: those who understand binary and those who don't"
]

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "Random Message Streaming Server is running!", "endpoints": ["/stream_message"]}

async def generate_random_messages() -> AsyncGenerator[str, None]:
    """Generate random messages with timestamps"""
    while True:
        timestamp = time.strftime("%d/%m/%y")
        base_message = random.choice(RANDOM_MESSAGES)
        message = f"{timestamp} {base_message}"
        
        # Format as Server-Sent Events
        data = {
            "timestamp": timestamp,
            "message": message,
            "id": random.randint(1000, 9999)
        }
        
        # SSE format: data: {json}\n\n
        yield f"data: {json.dumps(data)}\n\n"
        
        # Wait 1-3 seconds before next message
        await asyncio.sleep(random.uniform(1, 3))

@app.get("/stream_message")
async def stream_messages():
    """Stream random messages using Server-Sent Events"""
    return StreamingResponse(
        generate_random_messages(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*"
        }
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000, reload=True)
