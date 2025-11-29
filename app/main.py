from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({
        "service": "ci-cd-zero-to-hero",
        "hostname": socket.gethostname(),
        "environment": os.environ.get("APP_ENV", "dev"),
        "version": os.environ.get("APP_VERSION", "local")
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
