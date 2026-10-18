from contextlib import asynccontextmanager
import os
from pydantic import BaseModel
from typing import Annotated
import secrets
import socket

from fastapi import FastAPI, Depends, Request, HTTPException, Response, Cookie
from sqlalchemy import create_engine, text, URL


class AppConfig:
	DB_WRITE_HOST = os.getenv("DB_WRITE_HOST", "sd-db-0")
	DB_READ_HOST = os.getenv("DB_READ_HOST", "sd-db-1")
	DB_PORT = os.getenv("DB_PORT", "3306")
	DB_USER = os.getenv("DB_USER", "root")
	DB_PASS = os.getenv("DB_PASS", "root")


class User(BaseModel):
	id: int
	username: str
	password: str
	clicks: int


class UserSession(BaseModel):
	sessionId: str
	username: str


class Database:
	def __init__(self):
		self.read_engine = create_engine(
			URL.create(
				"mysql+pymysql",
				username=AppConfig.DB_USER,
				password=AppConfig.DB_PASS,
				host=AppConfig.DB_READ_HOST,
				port=int(AppConfig.DB_PORT),
				database="Sd",
			)
		)
		self.write_engine = create_engine(
			URL.create(
				"mysql+pymysql",
				username=AppConfig.DB_USER,
				password=AppConfig.DB_PASS,
				host=AppConfig.DB_WRITE_HOST,
				port=int(AppConfig.DB_PORT),
				database="Sd",
			)
		)
		self.users = dict()
		self.sessions = dict()
		self.idCnt = 0
		self.sessionCnt = 0

	def _getUser(self, conn, username: str) -> User | None:
		query = text("""
			SELECT * FROM Users WHERE username = :username
		""")
		res = conn.execute(query,
			{"username": username})
		user = res.mappings().first()
		if user:
			return User(id=user['id'], 
				username=user['username'],
				password=user['password'],
				clicks=user['clicks']
			)
		return None
		

	def getUser(self, username: str) -> User | None:
		with self.read_engine.connect() as conn:
			return self._getUser(conn, username)

	def createUser(self, username: str, password: str) -> User | None:
		with self.write_engine.connect() as conn:
			query = text("""
				INSERT IGNORE INTO Users (username, password) 
				VALUES (:username, :password)
			""")
			res = conn.execute(query, 
				{"username": username, "password": password})
			conn.commit()

			if res.rowcount == 0:
				return None

			return User(id=res.lastrowid, username=username, 
				password=password, clicks=0)

	def incrementClicks(self, username: str) -> User:
		with self.write_engine.connect() as conn:
			query = text("""
				UPDATE Users
				SET clicks = clicks + 1
				WHERE username = :username
			""")
			res = conn.execute(query,
				{"username": username})
			conn.commit()

			return self._getUser(conn, username)

	def getUserSessionById(self, sessionId: str = None) -> UserSession | None:
		with self.read_engine.connect() as conn:
			query = text("""
				SELECT * FROM Sessions
				WHERE sessionId = :sessionId
			""")
			res = conn.execute(query, {"sessionId": sessionId})
			session = res.mappings().first()
			if session:
				return UserSession(
					sessionId=sessionId,
					username=session['username']
				)
			return None

	def getUserSessionByUsername(self, username: str = None) -> UserSession | None:
		with self.write_engine.connect() as conn:
			query = text("""
				SELECT * FROM Sessions
				WHERE username = :username
			""")
			res = conn.execute(query, {"username": username})
			session = res.mappings().first()
			if session:
				return UserSession(
					sessionId=session['sessionId'],
					username=session['username']
				)
			return None

	def createUserSession(self, username: str) -> UserSession | None:
		with self.write_engine.connect() as conn:
			sessionId = secrets.token_hex(16)
			query = text("""
				INSERT INTO Sessions
				VALUES (:sessionId, :username)
			""")
			res = conn.execute(query, {"sessionId": sessionId,
				"username": username})
			conn.commit()

			if res.rowcount == 0:
				return None

			return UserSession(
				sessionId=sessionId,
				username=username
			)
		

@asynccontextmanager
async def lifespan(app: FastAPI):
	db = Database()
	
	yield {"db": db}

async def getDb(request: Request) -> Database:
	return request.state.db


app = FastAPI(lifespan=lifespan)


@app.middleware("http")
async def identify_backend(request: Request, call_next):
	response = await call_next(request)
	response.headers["X-Backend"] = socket.gethostname()
	return response


@app.get("/ping")
async def ping():
	return {"response": "pong"}


class LoginUser(BaseModel):
	username: str
	password: str


@app.post("/login")
async def loginUser(response: Response, user: LoginUser, db = Depends(getDb)):
	errorMsg = "username or password incorrect"

	dbUser = db.getUser(user.username)
	if dbUser is None or dbUser.password != user.password:
		raise HTTPException(status_code=404, detail=errorMsg)

	userSession = db.getUserSessionByUsername(user.username)
	if userSession is None:
		userSession = db.createUserSession(user.username)
	response.set_cookie(key="session_token", 
		value=f"{userSession.sessionId}")

	return dbUser.model_dump(exclude={"password"})


@app.post("/create")
async def createUser(user: LoginUser, db = Depends(getDb)):
	errorMsg = "username already exists"

	dbUser = db.createUser(user.username, user.password)
	if dbUser is None:
		raise HTTPException(status_code=404, detail=errorMsg)

	return dbUser.model_dump(exclude={"password"})


@app.get("/user/{username}")
async def getUser(username: str, db = Depends(getDb)):
	dbUser = db.getUser(username)
	if dbUser is None:
		raise HTTPException(status_code=404, detail="username not found")
	return dbUser.model_dump(exclude={"password", "id"})


async def getCurrentUser(
	session_token: Annotated[str | None, Cookie()] = None, 
	db = Depends(getDb)
):
	userSession = db.getUserSessionById(session_token)
	if userSession is None:
		raise HTTPException(status_code=401, detail="not logged in")

	user = db.getUser(userSession.username)
	if user is None:
		raise HTTPException(status_code=401, detail="invalid session")

	return user


@app.get("/me")
async def getMe(user: Annotated[User, Depends(getCurrentUser)]):
	return user.model_dump(exclude={"password"})


@app.post("/click")
async def click(
	user: Annotated[User, Depends(getCurrentUser)],
	db = Depends(getDb)
):
	user = db.incrementClicks(user.username)
	return user.model_dump(exclude={"password"})


