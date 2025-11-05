"""
Test suite for Flask microservice
"""
import pytest
import json
from app.main import app

@pytest.fixture
def client():
    """Create test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    """Test health check endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert 'timestamp' in data
    assert 'version' in data

def test_readiness_check(client):
    """Test readiness check endpoint"""
    response = client.get('/ready')
    # May return 503 if Redis/PostgreSQL not available in test
    assert response.status_code in [200, 503]

def test_users_get(client):
    """Test GET /api/users endpoint"""
    response = client.get('/api/users')
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert 'users' in data
    assert len(data['users']) == 2
    assert data['users'][0]['name'] == 'John Doe'

def test_users_post(client):
    """Test POST /api/users endpoint"""
    user_data = {
        'name': 'Test User',
        'email': 'test@example.com'
    }
    
    response = client.post('/api/users', 
                          data=json.dumps(user_data),
                          content_type='application/json')
    
    assert response.status_code == 201
    
    data = json.loads(response.data)
    assert data['message'] == 'User created successfully'
    assert data['user']['name'] == 'Test User'

def test_cache_endpoint_key_not_found(client):
    """Test cache endpoint with non-existent key"""
    response = client.get('/api/cache/nonexistent')
    # May return 404 or 503 depending on Redis availability
    assert response.status_code in [404, 503]

def test_invalid_endpoint(client):
    """Test invalid endpoint returns 404"""
    response = client.get('/invalid/endpoint')
    assert response.status_code == 404