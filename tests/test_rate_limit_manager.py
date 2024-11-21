"""Tests for rate limit manager."""
import pytest
from datetime import datetime, timedelta, timezone
from utils.rate_limit_manager import (
    RateLimitManager,
    RateLimitConfig,
    RateLimitException,
    BackoffStrategy
)

class MockResponse:
    """Mock response object with headers."""
    def __init__(self, headers):
        self.headers = headers

def test_backoff_strategy():
    """Test backoff delay calculations."""
    strategy = BackoffStrategy(
        initial_delay=1.0,
        max_delay=10.0,
        factor=2.0,
        enable_jitter=False
    )
    
    assert strategy.get_delay(0) == 1.0
    assert strategy.get_delay(1) == 2.0
    assert strategy.get_delay(2) == 4.0
    assert strategy.get_delay(3) == 8.0
    assert strategy.get_delay(4) == 10.0  # Max delay

def test_rate_limit_manager_initialization():
    """Test manager initialization with custom config."""
    config = RateLimitConfig(
        max_retries=3,
        initial_delay=2.0,
        max_delay=30.0
    )
    manager = RateLimitManager(config)
    
    assert manager.config.max_retries == 3
    assert manager.config.initial_delay == 2.0
    assert manager.config.max_delay == 30.0

def test_parse_rate_limit_headers():
    """Test parsing of GitHub API rate limit headers."""
    manager = RateLimitManager()
    now = datetime.now(timezone.utc)
    reset_time = int(now.timestamp())
    
    headers = {
        'X-RateLimit-Limit': '5000',
        'X-RateLimit-Remaining': '4999',
        'X-RateLimit-Reset': str(reset_time),
        'X-RateLimit-Used': '1'
    }
    
    info = manager._parse_rate_limit_headers(headers)
    
    assert info['limit'] == 5000
    assert info['remaining'] == 4999
    assert info['used'] == 1
    assert isinstance(info['reset'], datetime)

def test_should_retry_logic():
    """Test retry decision logic."""
    manager = RateLimitManager(
        RateLimitConfig(rate_limit_threshold=0.1)
    )
    
    # Set up test case
    operation_id = 'test_op'
    manager.retry_counts[operation_id] = 0
    
    # Test case: should retry (low remaining ratio)
    rate_info = {'remaining': 50, 'limit': 5000}
    assert manager._should_retry(operation_id, rate_info)
    
    # Test case: should not retry (high remaining ratio)
    rate_info = {'remaining': 4000, 'limit': 5000}
    assert not manager._should_retry(operation_id, rate_info)
    
    # Test case: should not retry (max retries reached)
    manager.retry_counts[operation_id] = 5
    assert not manager._should_retry(operation_id, rate_info)

def test_execute_with_retry_success():
    """Test successful execution with no retries needed."""
    manager = RateLimitManager()
    
    # Mock successful operation
    def operation():
        return MockResponse({
            'X-RateLimit-Limit': '5000',
            'X-RateLimit-Remaining': '4999',
            'X-RateLimit-Reset': str(int(datetime.now(timezone.utc).timestamp())),
            'X-RateLimit-Used': '1'
        })
    
    result = manager.execute_with_retry(operation, 'test_op')
    assert isinstance(result, MockResponse)

def test_execute_with_retry_rate_limit():
    """Test retry behavior when rate limit is exceeded."""
    manager = RateLimitManager(
        RateLimitConfig(
            max_retries=2,
            initial_delay=0.1,
            max_delay=0.2
        )
    )
    
    # Mock operation that fails with rate limit error
    attempt = 0
    def operation():
        nonlocal attempt
        attempt += 1
        if attempt < 2:
            raise Exception("rate limit exceeded")
        return MockResponse({
            'X-RateLimit-Limit': '5000',
            'X-RateLimit-Remaining': '4999',
            'X-RateLimit-Reset': str(int(datetime.now(timezone.utc).timestamp())),
            'X-RateLimit-Used': '1'
        })
    
    result = manager.execute_with_retry(operation, 'test_op')
    assert isinstance(result, MockResponse)
    assert attempt == 2

def test_rate_limit_exception():
    """Test rate limit exception creation and message."""
    reset_time = datetime.now(timezone.utc)
    exception = RateLimitException(reset_time, 0, 5000)
    
    assert str(exception).startswith("Rate limit exceeded")
    assert "0/5000 remaining" in str(exception)
    assert reset_time.isoformat() in str(exception)

def test_reset_counts():
    """Test retry count reset functionality."""
    manager = RateLimitManager()
    
    # Set up some retry counts
    manager.retry_counts = {
        'op1': 2,
        'op2': 3
    }
    
    # Test resetting specific operation
    manager.reset_counts('op1')
    assert 'op1' not in manager.retry_counts
    assert manager.retry_counts['op2'] == 3
    
    # Test resetting all operations
    manager.reset_counts()
    assert len(manager.retry_counts) == 0