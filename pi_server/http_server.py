from http.server import SimpleHTTPRequestHandler, HTTPServer
from urllib.parse import unquote
import os
from colorama import init
from colorama import Fore, Back, Style


####### WARNING ########
# This code is UNSAFE on purpose - It is for example purposes - do NOT use it to build a working web server
########################

# Init colorama - autoreset means it always resets the text color after each print saving you from having to do it each time
init(autoreset=True)

WEB_ROOT = os.path.abspath(os.path.dirname(__file__))
WEB_ROOT = os.path.join(WEB_ROOT, "public") # Add the public folder so that we don't server content from our current folder and give away things on accident

print(Fore.GREEN + f"Serving files from {WEB_ROOT}...")


class CustomHandler(SimpleHTTPRequestHandler):
    def normalize_path(self, path):
        print(Fore.YELLOW + f"Processing path: {path}...")
        # Adjust web path to local file path - WARNING - This is INTENTIONALLY VULERABLE!
        requested_path = unquote(path) # Deal with encoded characters like %20
        
        safe_path = os.path.normpath(
            os.path.join(WEB_ROOT, requested_path.lstrip("/"))  # Path comes in with a / at the begining - e.g. /hello - remove the / so we don't double it up
        )

        return safe_path
    
    def do_GET(self):
        print(Fore.MAGENTA + f"Get request recieved: {self.path}")
        # Custom behavior for certain paths
        if self.path == "/" or self.path == "":
            # Respond with a custom message
            print(Fore.CYAN + f"Returning hello world page.")
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"<html><body><h1>Hello, world!</h1></body></html>")
        elif self.path == "/on":
            print(Fore.GREEN + f"Turning On!")
            print(os.system("/usr/bin/ON"))
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"<html><body><h1>Device Turned On.</h1></body></html>")
        else:
            # Do our own file handling code

            # This is what is SHOULD be
            #file_to_serve = self.translate_path(self.path)

            # This is what we do to allow the .. hack
            self.path = self.path.replace("/dd", "/..") # Hack to make .. work with modern browsers - comment this to fix the .. issue

            # Convert any extra characters to a "normal" file path
            file_to_serve = self.normalize_path(self.path)
            
            if os.path.isdir(file_to_serve):
                # This is a folder, return an error.
                print(Fore.RED + f"Path is a folder, send back an error {file_to_serve}.")
                self.send_error(404, "File not found")
            elif os.path.isfile(file_to_serve):
                print(Fore.CYAN + f"File exists, send it {file_to_serve}.")
                self.send_response(200)
                # Guess the type of file (html, zip, picture?)
                self.send_header("Content-type", self.guess_type(file_to_serve))
                self.send_header("Content-Length", os.path.getsize(file_to_serve))
                self.end_headers()
                # Open the file and send it
                with open(file_to_serve, 'rb') as file:
                    self.wfile.write(file.read())
            else:
                # Not a directory or a file, must not exist, return an error
                print(Fore.RED + f"File wasn't found, return an error {file_to_serve}.")
                self.send_error(404, "File not found")


    def do_POST(self):
        # Example of handling a POST request
        print(Fore.MAGENTA + f"Data posted to: {self.path}")
        content_length = int(self.headers['Content-Length'])  # Get the size of data
        post_data = self.rfile.read(content_length)  # Read the posted data
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        response = f"<html><body><h1>POST Data Received</h1><p>{post_data.decode('utf-8')}</p></body></html>"
        self.wfile.write(response.encode('utf-8'))

# Define server address and port
server_address = ('', 8000)

# Create and start the server with the custom handler
httpd = HTTPServer(server_address, CustomHandler)
print(Fore.BLUE + f"Custom HTTP server running on port 8000...")
httpd.serve_forever()
