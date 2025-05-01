# Rate Limit Manager

A robust rate limit management system for GitHub API interactions with intelligent retry logic and exponential backoff.

## Features

- Intelligent rate limit detection and monitoring
- Exponential backoff with jitter
- Configurable retry strategies
- Comprehensive logging
- Pre-emptive throttling
- Detailed rate limit tracking

## Usage

```python
from utils.rate_limit_manager import RateLimitManager, RateLimitConfig

# Create a manager with custom configuration
config = RateLimitConfig(
    max_retries=5,
    initial_delay=1.0,
    max_delay=3600.0,
    backoff_factor=2.0,
    rate_limit_threshold=0.1
)
manager = RateLimitManager(config)

# Use the manager to execute API operations
def github_api_call():
    response = requests.get('https://api.github.com/user')
    return response

result = manager.execute_with_retry(github_api_call, 'get_user')
```

## Configuration

The `RateLimitConfig` class supports the following parameters:

- `max_retries`: Maximum number of retry attempts (default: 5)
- `initial_delay`: Initial delay in seconds (default: 1.0)
- `max_delay`: Maximum delay in seconds (default: 3600.0)
- `backoff_factor`: Multiplication factor for exponential backoff (default: 2.0)
- `rate_limit_threshold`: Threshold for pre-emptive throttling (default: 0.1)
- `enable_jitter`: Whether to add random jitter to delays (default: True)
- `jitter_factor`: Maximum jitter as a fraction of delay (default: 0.1)

## Testing

Run the tests using pytest:

```bash
pytest tests/test_rate_limit_manager.py
```

## Implementation Details

### Rate Limit Detection

The manager monitors GitHub API rate limits through response headers:
- X-RateLimit-Limit
- X-RateLimit-Remaining
- X-RateLimit-Reset
- X-RateLimit-Used

### Backoff Strategy

The exponential backoff is implemented with the following formula:
```python
delay = min(initial_delay * (backoff_factor ** attempt), max_delay)
if enable_jitter:
    delay += random.uniform(0, jitter_factor * delay)
```

### Pre-emptive Throttling

The manager will start throttling requests when the remaining rate limit falls below the configured threshold:
```python
remaining_ratio = rate_info['remaining'] / rate_info['limit']
if remaining_ratio <= rate_limit_threshold:
    # Apply backoff
```