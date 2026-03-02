"""Authentication API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.user import User
from ..schemas.user import UserLogin, UserRegister, Token, UserResponse, UserWithToken
from ..services.auth_service import (
    verify_password,
    get_password_hash,
    create_access_token,
    get_current_user_required,
)

router = APIRouter()


@router.post("/register", response_model=UserWithToken, status_code=status.HTTP_201_CREATED)
def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """Register a new user account."""
    import traceback
    try:
        # Check if email already exists
        existing_user = db.query(User).filter(User.email == user_data.email).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered",
            )
        
        # Create new user
        password_hash = get_password_hash(user_data.password)
        user = User(
            email=user_data.email,
            password_hash=password_hash,
            name=user_data.name,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        
        # Generate token
        access_token = create_access_token(user.id)
        
        return UserWithToken(
            user=UserResponse.model_validate(user),
            token=Token(access_token=access_token),
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"Registration error: {e}")
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}",
        )


@router.post("/login", response_model=UserWithToken)
def login(user_data: UserLogin, db: Session = Depends(get_db)):
    """Login with email and password."""
    user = db.query(User).filter(User.email == user_data.email).first()
    
    if not user or not verify_password(user_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    
    access_token = create_access_token(user.id)
    
    return UserWithToken(
        user=UserResponse.model_validate(user),
        token=Token(access_token=access_token),
    )


@router.post("/login/form", response_model=Token)
def login_form(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    """Login endpoint for OAuth2 form (Swagger UI compatibility)."""
    user = db.query(User).filter(User.email == form_data.username).first()
    
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    
    access_token = create_access_token(user.id)
    return Token(access_token=access_token)


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user_required)):
    """Get current authenticated user."""
    return current_user


@router.post("/logout")
def logout():
    """Logout current user. Token invalidation handled client-side."""
    return {"message": "Successfully logged out"}
