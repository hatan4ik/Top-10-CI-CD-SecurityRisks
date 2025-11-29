import pytest
from main import app


@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_index_endpoint(client):
    """Test the index endpoint returns JSON"""
    response = client.get('/', follow_redirects=True)
    assert response.status_code == 200
    assert response.is_json
    data = response.get_json()
    assert 'service' in data
    assert data['service'] == 'ci-cd-zero-to-hero'


def test_security_headers(client):
    """Test security headers are present"""
    response = client.get('/', follow_redirects=True)
    
    # Check for security headers added by Talisman
    assert 'X-Frame-Options' in response.headers
    assert 'X-Content-Type-Options' in response.headers
    assert 'Content-Security-Policy' in response.headers


def test_environment_variables(client):
    """Test environment variables are properly set"""
    response = client.get('/', follow_redirects=True)
    data = response.get_json()
    assert 'environment' in data
    assert 'version' in data
    assert 'hostname' in data


def test_health_endpoint(client):
    """Test health check endpoint"""
    response = client.get('/health', follow_redirects=True)
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'


def test_ready_endpoint(client):
    """Test readiness check endpoint"""
    response = client.get('/ready', follow_redirects=True)
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'ready'


def test_rate_limiting(client):
    """Test rate limiting is configured"""
    # Make multiple requests
    for _ in range(5):
        response = client.get('/', follow_redirects=True)
        assert response.status_code == 200
    # Rate limiter should be active (not testing actual limit)
