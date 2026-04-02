import os
from locust import HttpUser, TaskSet, task, between

class UserBehavior(TaskSet):
    @task
    def get(self):
        with self.client.get("/", catch_response=True) as resp:
            if resp.status_code != 200:
                resp.failure(f"Failed! Status code: {resp.status_code}, Response: {resp.text}")
            else:
                resp.success()

class WebsiteUser(HttpUser):
    tasks = [UserBehavior]
    wait_time = between(1, 2)
    host = os.environ.get("TARGET_HOST", "http://localhost:8080")  # Override with TARGET_HOST for deployed endpoints

if __name__ == "__main__":
    os.system("locust -f locustfile.py")
