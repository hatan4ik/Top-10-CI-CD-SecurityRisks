from flask import Flask, jsonify
from flask_talisman import Talisman
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import os
import socket
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Security headers
Talisman(app, 
    force_https=False,  # Set to True in production with proper TLS
    strict_transport_security=True,
    content_security_policy={
        'default-src': "'self'"
    }
)

# Rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["100 per hour", "20 per minute"],
    storage_uri="memory://"
)

@app.route("/")
@limiter.limit("50 per minute")
def index():
    logger.info(f"Index endpoint accessed from {get_remote_address()}")
    
    # Validate environment variables
    env = os.environ.get("APP_ENV", "dev")
    if env not in ["dev", "staging", "production"]:
        env = "dev"
    
    return jsonify({
        "service": "ci-cd-zero-to-hero",
        "hostname": socket.gethostname(),
        "environment": env,
        "version": os.environ.get("APP_VERSION", "local")
    })

@app.route("/health")
@limiter.exempt
def health():
    """Health check endpoint for orchestrators"""
    return jsonify({"status": "healthy"}), 200

@app.route("/ready")
@limiter.exempt
def ready():
    """Readiness check endpoint for orchestrators"""
    return jsonify({"status": "ready"}), 200

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    if not (1024 <= port <= 65535):
        port = 8080
    logger.info(f"Starting application on port {port}")
    app.run(host="0.0.0.0", port=port)
