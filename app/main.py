"""
Flask Microservice - Main Application
Production-ready Flask app with health checks and metrics
"""
from flask import Flask, jsonify, request
from prometheus_flask_exporter import PrometheusMetrics
import os
import logging
import redis
import psycopg2
from datetime import datetime

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
metrics = PrometheusMetrics(app)

# Database connections
redis_client = None
postgres_conn = None

def init_connections():
    """Initialize database connections"""
    global redis_client, postgres_conn
    
    try:
        # Redis connection
        redis_host = os.getenv('REDIS_HOST', 'localhost')
        redis_port = int(os.getenv('REDIS_PORT', 6379))
        redis_client = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)
        
        # PostgreSQL connection
        postgres_conn = psycopg2.connect(
            host=os.getenv('POSTGRES_HOST', 'localhost'),
            database=os.getenv('POSTGRES_DB', 'devops_app'),
            user=os.getenv('POSTGRES_USER', 'postgres'),
            password=os.getenv('POSTGRES_PASSWORD', 'password')
        )
        logger.info("Database connections initialized")
    except Exception as e:
        logger.error(f"Failed to initialize connections: {e}")

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': os.getenv('APP_VERSION', '1.0.0')
    })

@app.route('/ready')
def readiness_check():
    """Readiness check endpoint"""
    try:
        # Check Redis
        if redis_client:
            redis_client.ping()
        
        # Check PostgreSQL
        if postgres_conn:
            cursor = postgres_conn.cursor()
            cursor.execute('SELECT 1')
            cursor.close()
        
        return jsonify({'status': 'ready'})
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        return jsonify({'status': 'not ready', 'error': str(e)}), 503

@app.route('/api/users', methods=['GET', 'POST'])
def users():
    """Users API endpoint"""
    if request.method == 'GET':
        return jsonify({
            'users': [
                {'id': 1, 'name': 'John Doe', 'email': 'john@example.com'},
                {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com'}
            ]
        })
    
    elif request.method == 'POST':
        user_data = request.get_json()
        # In production, this would save to database
        return jsonify({
            'message': 'User created successfully',
            'user': user_data
        }), 201

@app.route('/api/cache/<key>')
def get_cache(key):
    """Get value from Redis cache"""
    try:
        if redis_client:
            value = redis_client.get(key)
            if value:
                return jsonify({'key': key, 'value': value})
            else:
                return jsonify({'error': 'Key not found'}), 404
        else:
            return jsonify({'error': 'Redis not available'}), 503
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    init_connections()
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)