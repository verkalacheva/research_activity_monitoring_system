import asyncio
import os
from concurrent import futures
import grpc
from pb import integrations_pb2_grpc
from interfaces.grpc_handler import GrpcHandler
from health_http import start_background

async def serve():
    # По умолчанию допускаем довольно редкий client keepalive; при burst-нагрузке не "штрафуем" соединение ping-strikes.
    min_ping_ms = int(os.getenv("GRPC_HTTP2_MIN_RECV_PING_INTERVAL_MS", "59000"))
    max_ping_strikes = int(os.getenv("GRPC_HTTP2_MAX_PING_STRIKES", "0"))

    options = [
        ('grpc.max_send_message_length', 50 * 1024 * 1024),
        ('grpc.max_receive_message_length', 50 * 1024 * 1024),
        ('grpc.http2.min_recv_ping_interval_without_data_ms', min_ping_ms),
        ('grpc.http2.max_ping_strikes', max_ping_strikes),
    ]

    server = grpc.aio.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=options
    )
    
    integrations_pb2_grpc.add_IntegrationServiceServicer_to_server(GrpcHandler(), server)
    
    port = os.getenv("PORT", "50053")
    server.add_insecure_port(f"[::]:{port}")
    
    print(f"Crawler gRPC server starting on port {port} (Clean Architecture)...")
    await server.start()
    await server.wait_for_termination()

if __name__ == "__main__":
    start_background()
    asyncio.run(serve())
