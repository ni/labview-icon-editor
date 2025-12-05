import requests
import mysql.connector
import os
from datetime import datetime
import sys

# Environment variables
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
ORG_NAME = os.getenv("ORG_NAME")
REQUIRED_TOPIC = os.getenv("REQUIRED_TOPIC")
MYSQL_HOST = os.getenv("MYSQL_HOST")
MYSQL_USER = os.getenv("MYSQL_USER")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD")
MYSQL_DATABASE = os.getenv("MYSQL_DATABASE")
DEBUG = (os.getenv("DEBUG", "true").lower() == "true")

HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3.star+json"
}

def debug_print(msg):
    if DEBUG:
        print(f"[DEBUG] {msg}")

def validate_env():
    required_vars = {
        "GITHUB_TOKEN": GITHUB_TOKEN,
        "ORG_NAME": ORG_NAME,
        "REQUIRED_TOPIC": REQUIRED_TOPIC,
        "MYSQL_HOST": MYSQL_HOST,
        "MYSQL_USER": MYSQL_USER,
        "MYSQL_PASSWORD": MYSQL_PASSWORD,
        "MYSQL_DATABASE": MYSQL_DATABASE
    }
    missing = [k for k,v in required_vars.items() if not v]
    if missing:
        print(f"Error: Missing required environment variables: {', '.join(missing)}")
        sys.exit(1)

def connect_to_mysql():
    try:
        conn = mysql.connector.connect(
            host=MYSQL_HOST,
            user=MYSQL_USER,
            password=MYSQL_PASSWORD,
            database=MYSQL_DATABASE
        )
        return conn
    except mysql.connector.Error as err:
        print(f"Error connecting to MySQL: {err}")
        sys.exit(1)

def create_tables(cursor):
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS traffic_views (
            id INT AUTO_INCREMENT PRIMARY KEY,
            repo_owner VARCHAR(255),
            repo_name VARCHAR(255),
            timestamp DATETIME,
            count INT,
            uniques INT,
            forked_from VARCHAR(255),
            UNIQUE KEY (repo_owner, repo_name, timestamp)
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS traffic_clones (
            id INT AUTO_INCREMENT PRIMARY KEY,
            repo_owner VARCHAR(255),
            repo_name VARCHAR(255),
            timestamp DATETIME,
            count INT,
            uniques INT,
            forked_from VARCHAR(255),
            UNIQUE KEY (repo_owner, repo_name, timestamp)
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS stargazers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            repo_owner VARCHAR(255),
            repo_name VARCHAR(255),
            user_login VARCHAR(255),
            user_id INT,
            node_id VARCHAR(255),
            starred_url TEXT,
            type VARCHAR(255),
            site_admin BOOLEAN,
            starred_at DATETIME,
            forked_from VARCHAR(255),
            organization VARCHAR(255),
            UNIQUE KEY (repo_owner, repo_name, node_id)
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS pull_requests (
            id INT AUTO_INCREMENT PRIMARY KEY,
            repo_owner VARCHAR(255),
            repo_name VARCHAR(255),
            pr_number INT,
            title TEXT,
            state VARCHAR(50),
            created_at DATETIME,
            updated_at DATETIME,
            closed_at DATETIME,
            merged_at DATETIME,
            user_login VARCHAR(255),
            user_id INT,
            html_url TEXT,
            forked_from VARCHAR(255),
            organization VARCHAR(255),
            UNIQUE KEY (repo_owner, repo_name, pr_number)
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS contributors (
            id INT AUTO_INCREMENT PRIMARY KEY,
            repo_owner VARCHAR(255),
            repo_name VARCHAR(255),
            user_login VARCHAR(255),
            user_id INT,
            contributions INT,
            forked_from VARCHAR(255),
            timestamp DATETIME,
            organization VARCHAR(255),
            UNIQUE KEY (repo_owner, repo_name, user_login, contributions)
        )
    """)

def convert_to_mysql_datetime(iso_timestamp):
    if not iso_timestamp:
        return None
    try:
        return datetime.strptime(iso_timestamp.replace("Z", ""), "%Y-%m-%dT%H:%M:%S")
    except ValueError as e:
        print(f"Error parsing timestamp '{iso_timestamp}': {e}")
        return None

def handle_403(response):
    rate_limit_remaining = response.headers.get('X-RateLimit-Remaining')
    try:
        if rate_limit_remaining is not None and int(rate_limit_remaining) == 0:
            print("Rate limit exceeded. Please wait for your limit to reset or use a token with higher limits.")
            return
    except ValueError:
        pass
    try:
        data = response.json()
        message = data.get("message", "")
        if "access" in message.lower() or "permission" in message.lower() or "resource not accessible" in message.lower():
            print("Permission issue encountered. Check if your token has the necessary scopes/permissions.")
        else:
            print(f"Error 403 encountered: {message}")
    except ValueError:
        print("A 403 error occurred, but the response could not be parsed. Check your token or permissions.")

def fetch_data(url):
    debug_print(f"Fetching data from: {url}")
    try:
        response = requests.get(url, headers=HEADERS, timeout=10)
    except requests.RequestException as e:
        print(f"Network error fetching data from {url}: {e}")
        return None

    debug_print(f"Response status: {response.status_code}")
    if response.status_code == 200:
        return response.json()
    elif response.status_code == 403:
        handle_403(response)
    else:
        print(f"Error fetching data from {url}: {response.text}")
    return None

def fetch_all_pages(url):
    results = []
    next_url = url
    while next_url:
        debug_print(f"Fetching page: {next_url}")
        try:
            response = requests.get(next_url, headers=HEADERS, timeout=10)
        except requests.RequestException as e:
            print(f"Network error on pagination fetch: {e}")
            break

        debug_print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            if isinstance(data, list):
                if not data:
                    break
                results.extend(data)
            elif isinstance(data, dict) and "items" in data:
                results.extend(data["items"])
            else:
                if isinstance(data, dict) and data:
                    break
                else:
                    break

            links = response.headers.get('Link', '')
            next_link = None
            if links:
                for part in links.split(','):
                    if 'rel="next"' in part:
                        next_link = part.split(';')[0].strip('<> ')
                        break
            next_url = next_link
        elif response.status_code == 403:
            handle_403(response)
            break
        else:
            print(f"Error fetching data (pagination) from {next_url}: {response.text}")
            break
    return results

user_org_cache = {}

def get_user_organization(user_login, cache):
    if not user_login:
        return None
    if user_login in cache:
        return cache[user_login]

    orgs_url = f"https://api.github.com/users/{user_login}/orgs"
    orgs = fetch_data(orgs_url)
    if isinstance(orgs, list) and len(orgs) > 0:
        user_org = orgs[0].get("login")
    else:
        user_org = None

    cache[user_login] = user_org
    return user_org

def store_traffic_views(data, owner, repo, forked_from, cursor):
    views = data.get("views", []) if data else []
    for view in views:
        timestamp = convert_to_mysql_datetime(view["timestamp"])
        if timestamp:
            cursor.execute("""
                INSERT INTO traffic_views (repo_owner, repo_name, timestamp, count, uniques, forked_from)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE count=count
            """, (owner, repo, timestamp, view["count"], view["uniques"], forked_from))

def store_traffic_clones(data, owner, repo, forked_from, cursor):
    clones = data.get("clones", []) if data else []
    for clone in clones:
        timestamp = convert_to_mysql_datetime(clone["timestamp"])
        if timestamp:
            cursor.execute("""
                INSERT INTO traffic_clones (repo_owner, repo_name, timestamp, count, uniques, forked_from)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE count=count
            """, (owner, repo, timestamp, clone["count"], clone["uniques"], forked_from))

def store_stargazers(stargazers_data, owner, repo, forked_from, cursor):
    if not isinstance(stargazers_data, list):
        return
    for s in stargazers_data:
        starred_at = convert_to_mysql_datetime(s.get("starred_at"))
        user = s.get("user", {})
        user_login = user.get("login")
        user_id = user.get("id")
        node_id = user.get("node_id")
        starred_url = user.get("starred_url")
        user_type = user.get("type")
        site_admin = user.get("site_admin", False)

        organization = get_user_organization(user_login, user_org_cache)

        # Update organization on duplicates too
        cursor.execute("""
            INSERT INTO stargazers (
                repo_owner, repo_name, user_login, user_id, node_id, starred_url,
                type, site_admin, starred_at, forked_from, organization
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE node_id=node_id, organization=VALUES(organization)
        """, (
            owner, repo, user_login, user_id, node_id, starred_url,
            user_type, site_admin, starred_at, forked_from, organization
        ))

def store_pull_requests(pr_data, owner, repo, forked_from, cursor):
    if not isinstance(pr_data, list):
        return
    for pr in pr_data:
        pr_number = pr.get("number")
        title = pr.get("title")
        state = pr.get("state")
        created_at = convert_to_mysql_datetime(pr.get("created_at"))
        updated_at = convert_to_mysql_datetime(pr.get("updated_at"))
        closed_at = convert_to_mysql_datetime(pr.get("closed_at"))
        merged_at = convert_to_mysql_datetime(pr.get("merged_at"))
        user_login = pr.get("user", {}).get("login")
        user_id = pr.get("user", {}).get("id")
        html_url = pr.get("html_url")
        organization = get_user_organization(user_login, user_org_cache)

        cursor.execute("""
            INSERT INTO pull_requests (
                repo_owner, repo_name, pr_number, title, state, created_at, updated_at,
                closed_at, merged_at, user_login, user_id, html_url, forked_from, organization
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                title=VALUES(title),
                state=VALUES(state),
                user_login=VALUES(user_login),
                user_id=VALUES(user_id),
                html_url=VALUES(html_url),
                forked_from=VALUES(forked_from),
                organization=VALUES(organization),
                updated_at = CASE WHEN updated_at IS NULL AND VALUES(updated_at) IS NOT NULL THEN VALUES(updated_at) ELSE updated_at END,
                closed_at = CASE WHEN closed_at IS NULL AND VALUES(closed_at) IS NOT NULL THEN VALUES(closed_at) ELSE closed_at END,
                merged_at = CASE WHEN merged_at IS NULL AND VALUES(merged_at) IS NOT NULL THEN VALUES(merged_at) ELSE merged_at END
        """, (
            owner, repo, pr_number, title, state, created_at, updated_at,
            closed_at, merged_at, user_login, user_id, html_url, forked_from, organization
        ))

def store_contributors(contrib_data, owner, repo, forked_from, cursor):
    if not isinstance(contrib_data, list):
        return
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    for contrib in contrib_data:
        user_login = contrib.get("login")
        user_id = contrib.get("id")
        contributions = contrib.get("contributions")
        organization = get_user_organization(user_login, user_org_cache)

        # Update organization on duplicates
        cursor.execute("""
            INSERT INTO contributors (repo_owner, repo_name, user_login, user_id, contributions, forked_from, timestamp, organization)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE user_id=user_id, organization=VALUES(organization)
        """, (owner, repo, user_login, user_id, contributions, forked_from, now, organization))

def process_repository(owner, repo, cursor, conn, forked_from=None):
    base_url = f"https://api.github.com/repos/{owner}/{repo}"

    # Traffic views
    views_data = fetch_data(f"{base_url}/traffic/views")
    store_traffic_views(views_data, owner, repo, forked_from, cursor)

    # Traffic clones
    clones_data = fetch_data(f"{base_url}/traffic/clones")
    store_traffic_clones(clones_data, owner, repo, forked_from, cursor)

    # Stargazers (paginated)
    stargazers = fetch_all_pages(f"{base_url}/stargazers?per_page=100")
    store_stargazers(stargazers, owner, repo, forked_from, cursor)

    # Pull Requests (paginated)
    pull_requests = fetch_all_pages(f"{base_url}/pulls?state=all&per_page=100")
    store_pull_requests(pull_requests, owner, repo, forked_from, cursor)

    # Contributors (paginated)
    contributors = fetch_all_pages(f"{base_url}/contributors?per_page=100&anon=1")
    store_contributors(contributors, owner, repo, forked_from, cursor)

    # Commit after processing this repository
    conn.commit()

    # Forks (paginated)
    forks = fetch_all_pages(f"{base_url}/forks?per_page=100")
    if isinstance(forks, list):
        for fork in forks:
            fork_owner = fork["owner"]["login"]
            fork_name = fork["name"]
            debug_print(f"Processing forked repository: {fork_owner}/{fork_name}")
            process_repository(fork_owner, fork_name, cursor, conn, forked_from=f"{owner}/{repo}")

def has_required_topic(owner, repo, required_topic):
    url = f"https://api.github.com/repos/{owner}/{repo}/topics"
    response = fetch_data(url)
    if response and "names" in response:
        return required_topic in response["names"]
    return False

def check_token_validity():
    resp = fetch_data("https://api.github.com/user")
    if not resp or not resp.get("login"):
        print("Invalid or insufficiently scoped GitHub token. Exiting.")
        sys.exit(1)

def main():
    validate_env()
    check_token_validity()

    repos = fetch_all_pages(f"https://api.github.com/orgs/{ORG_NAME}/repos?per_page=100")
    if not repos:
        print(f"No repositories found for organization: {ORG_NAME}")
        return

    conn = connect_to_mysql()
    cursor = conn.cursor()

    create_tables(cursor)

    for repo in repos:
        owner = repo["owner"]["login"]
        repo_name = repo["name"]
        if has_required_topic(owner, repo_name, REQUIRED_TOPIC):
            print(f"Processing repository: {owner}/{repo_name}")
            process_repository(owner, repo_name, cursor, conn)

    # Final commit
    conn.commit()
    cursor.close()
    conn.close()

if __name__ == "__main__":
    main()