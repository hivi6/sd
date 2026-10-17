from contextlib import asynccontextmanager
from pydantic import BaseModel
from typing import Annotated

from fastapi import FastAPI, Depends, Request, HTTPException, Response, Cookie


class User(BaseModel):
	id: int
	username: str
	password: str
	clicks: int


class UserSession(BaseModel):
	username: str
	sessionToken: int


class Database:
	def __init__(self):
		self.users = dict()
		self.sessions = dict()
		self.idCnt = 0
		self.sessionCnt = 0

	def getUser(self, username: str) -> User | None:
		if username is None:
			raise ValueError()
		return self.users.get(username, None)

	def createUser(self, username: str, password: str) -> User | None:
		if username in self.users:
			return None
		user = User(id=self.idCnt, username=username, 
			password=password, clicks=0)
		self.users[username] = user
		self.idCnt += 1
		return user

	def getUserSession(self, sessionToken: str) -> UserSession:
		return self.sessions.get(sessionToken, None)

	def createUserSession(self, username: str) -> UserSession:
		userSession = UserSession(username=username, 
			sessionToken=self.sessionCnt)
		self.sessions[str(self.sessionCnt)] = userSession
		self.sessionCnt += 1
		return userSession
		

@asynccontextmanager
async def lifespan(app: FastAPI):
	db = Database()
	
	yield {"db": db}

async def getDb(request: Request) -> Database:
	return request.state.db


app = FastAPI(lifespan=lifespan)


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

	userSession = db.createUserSession(user.username)
	response.set_cookie(key="session_token", 
		value=f"{userSession.sessionToken}")

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
	userSession = db.getUserSession(session_token)
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
async def click(user: Annotated[User, Depends(getCurrentUser)]):
	user.clicks += 1
	return user.model_dump(exclude={"password"})


