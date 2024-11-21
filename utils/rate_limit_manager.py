"""
Rate limit manager for GitHub API interactions.
Implements intelligent retry logic with exponential backoff.
"""
import random
import time
import logging
from typing import Any, Callable, Dict, Optional, TypeVar
from datetime import datetime, timezone
from dataclasses import dataclass

logger = logging.getLogger(__name__)

T = TypeVar('T')

@dataclass
class RateLimitConfig:
    """Configuration for rate limit handling."""
    max_retries: int = 5
    initial_delay: float = 1.0  # seconds
    max_delay: float = 3600.0   # 1 hour
    backoff_factor: float = 2.0
    rate_limit_threshold: float = 0.1  # 10% remaining
    enable_jitter: bool = True
    jitter_factor: float = 0.1

class RateLimitException(Exception):
    """Exception raised when rate limit is exceeded."""
    def __init__(self, reset_time: datetime, remaining: int, limit: int):
        self.reset_time = reset_time
        self.remaining = remaining
        self.limit = limit
        super().__init__(
            f"Rate limit exceeded. {remaining}/{limit} remaining. "
            f"Resets at {reset_time.isoformat()}"
        )

class BackoffStrategy:
    """Implements exponential backoff with optional jitter."""
    
    def __init__(
        self,
        initial_delay: float,
        max_delay: float,
        factor: float,
        enable_jitter: bool = True,
        jitter_factor: float = 0.1
    ):
        self.initial_delay = initial_delay
        self.max_delay = max_delay
        self.factor = factor
        self.enable_jitter = enable_jitter
        self.jitter_factor = jitter_factor

    def get_delay(self, attempt: int) -> float:
        """Calculate delay for given attempt number."""
        delay = min(
            self.initial_delay * (self.factor ** attempt),
            self.max_delay
        )
        
        if self.enable_jitter:
            jitter = random.uniform(0, self.jitter_factor * delay)
            delay += jitter
            
        return delay

class RateLimitManager:
    """Manages GitHub API rate limits with retry logic."""
    
    def __init__(self, config: Optional[RateLimitConfig] = None):
        self.config = config or RateLimitConfig()
        self.backoff = BackoffStrategy(
            initial_delay=self.config.initial_delay,
            max_delay=self.config.max_delay,
            factor=self.config.backoff_factor,
            enable_jitter=self.config.enable_jitter,
            jitter_factor=self.config.jitter_factor
        )
        self.rate_limits: Dict[str, Dict[str, Any]] = {}
        self.retry_counts: Dict[str, int] = {}

    def _parse_rate_limit_headers(self, headers: Dict[str, str]) -> Dict[str, Any]:
        """Parse GitHub API rate limit headers."""
        try:
            return {
                'limit': int(headers.get('X-RateLimit-Limit', 0)),
                'remaining': int(headers.get('X-RateLimit-Remaining', 0)),
                'reset': datetime.fromtimestamp(
                    int(headers.get('X-RateLimit-Reset', 0)),
                    timezone.utc
                ),
                'used': int(headers.get('X-RateLimit-Used', 0))
            }
        except (ValueError, TypeError) as e:
            logger.warning(f"Error parsing rate limit headers: {e}")
            return {}

    def _should_retry(self, operation_id: str, rate_info: Dict[str, Any]) -> bool:
        """Determine if operation should be retried."""
        if self.retry_counts[operation_id] >= self.config.max_retries:
            return False
            
        remaining_ratio = rate_info['remaining'] / rate_info['limit']
        return remaining_ratio <= self.config.rate_limit_threshold

    def _wait_for_reset(self, reset_time: datetime) -> None:
        """Wait until rate limit reset time."""
        now = datetime.now(timezone.utc)
        if reset_time > now:
            wait_seconds = (reset_time - now).total_seconds()
            logger.info(f"Waiting {wait_seconds:.2f} seconds for rate limit reset")
            time.sleep(wait_seconds)

    def execute_with_retry(
        self,
        operation: Callable[[], T],
        operation_id: Optional[str] = None
    ) -> T:
        """Execute operation with retry logic."""
        op_id = operation_id or str(hash(operation))
        self.retry_counts.setdefault(op_id, 0)

        while self.retry_counts[op_id] < self.config.max_retries:
            try:
                result = operation()
                
                # Update rate limits from response headers if available
                if hasattr(result, 'headers'):
                    rate_info = self._parse_rate_limit_headers(result.headers)
                    if rate_info:
                        self.rate_limits[op_id] = rate_info
                        
                        # Log rate limit status
                        logger.info(
                            f"Rate limit status for {op_id}: "
                            f"{rate_info['remaining']}/{rate_info['limit']} "
                            f"remaining (Reset: {rate_info['reset'].isoformat()})"
                        )
                        
                        # Check if we should preemptively back off
                        if self._should_retry(op_id, rate_info):
                            delay = self.backoff.get_delay(self.retry_counts[op_id])
                            logger.info(f"Preemptive backoff for {delay:.2f} seconds")
                            time.sleep(delay)
                
                return result

            except Exception as e:
                self.retry_counts[op_id] += 1
                
                if "rate limit exceeded" in str(e).lower():
                    rate_info = self.rate_limits.get(op_id, {})
                    if rate_info and rate_info.get('reset'):
                        logger.warning(
                            f"Rate limit exceeded. Attempt {self.retry_counts[op_id]} "
                            f"of {self.config.max_retries}"
                        )
                        self._wait_for_reset(rate_info['reset'])
                    else:
                        delay = self.backoff.get_delay(self.retry_counts[op_id])
                        logger.warning(
                            f"Rate limit exceeded with unknown reset time. "
                            f"Backing off for {delay:.2f} seconds"
                        )
                        time.sleep(delay)
                else:
                    raise

        raise RuntimeError(
            f"Operation {op_id} failed after {self.config.max_retries} retries"
        )

    def reset_counts(self, operation_id: Optional[str] = None) -> None:
        """Reset retry counts for given operation or all operations."""
        if operation_id:
            self.retry_counts.pop(operation_id, None)
        else:
            self.retry_counts.clear()

    def get_rate_limit_info(self, operation_id: str) -> Dict[str, Any]:
        """Get rate limit information for operation."""
        return self.rate_limits.get(operation_id, {})