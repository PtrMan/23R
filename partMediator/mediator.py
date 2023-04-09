import socket
import threading

host = 'localhost'  # the server's hostname or IP address
port = 1237

clients = []

def handle_client(conn, addr):
    global clients
    clients.append(conn)
    print(f'Connected by {addr}')

    with conn:
        while True:
            data = conn.recv(4096)
            if not data:
                break
            print(f'Received from {addr}: {data.decode()}')
            for client in clients:
                if client != conn:
                    client.sendall(data)
    clients.remove(conn)
    print(f'Connection closed by {addr}')

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind((host, port))
    s.listen()
    print(f'Server listening on {host}:{port}')
    while True:
        conn, addr = s.accept()
        threading.Thread(target=handle_client, args=(conn, addr)).start()
