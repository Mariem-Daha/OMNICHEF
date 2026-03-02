"""Authentication service for JWT tokens and password hashing."""

from datetime import datetime, timedelta, timezone
from uuid import UUID
from jose import JWTError, jwt
import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from ..config import get_settings
from ..database import get_db
from ..models.user import User
from ..schemas.user import TokenData

settings = get_settings()

# OAuth2 scheme for token extraction
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return bcrypt.checkpw(
        plain_password.encode('utf-8'),
        hashed_password.encode('utf-8')
    )


def get_password_hash(password: str) -> str:
    """Hash a password using bcrypt."""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')


def create_access_token(user_id: UUID) -> str:
    """Create a JWT access token for a user."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    to_encode = {
        "sub": str(user_id),
        "exp": expire,
    }
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)


def decode_token(token: str) -> TokenData | None:
    """Decode and validate a JWT token."""
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        user_id: str = payload.get("sub")
        if user_id is None:
            return None
        return TokenData(user_id=UUID(user_id))
    except JWTError:
        return None


def get_current_user(
    token: str | None = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User | None:
    """Get current user from JWT token. Returns None if not authenticated."""
    if token is None:
        return None
    
    token_data = decode_token(token)
    if token_data is None or token_data.user_id is None:
        return None
    
    user = db.query(User).filter(User.id == token_data.user_id).first()
    return user


def get_current_user_optional(
    token: str | None = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User | None:
    """Get current user from JWT token (optional). Returns None if not authenticated."""
    return get_current_user(token, db)


def get_current_user_required(
    user: User | None = Depends(get_current_user),
) -> User:
    """Get current user, raising 401 if not authenticated."""
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user
