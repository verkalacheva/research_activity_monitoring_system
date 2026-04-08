import asyncio
import os
from concurrent import futures
import grpc
from pb import integrations_pb2_grpc
from interfaces.grpc_handler import GrpcHandler

async def serve():
    # Increase max message size if needed
    options = [
        ('grpc.max_send_message_length', 50 * 1024 * 1024),
        ('grpc.max_receive_message_length', 50 * 1024 * 1024)
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
    # Ensure crawler_service is in sys.path if needed, 
    # but since it's the root of the service, it should be fine.
    asyncio.run(serve())
