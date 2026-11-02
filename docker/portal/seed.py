import os
import sqlite3

DB_PATH = "/var/lib/portal/portal.db"

if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

conn = sqlite3.connect(DB_PATH)
conn.execute("CREATE TABLE staff (id INTEGER PRIMARY KEY, username TEXT, password TEXT)")
admin_pw = os.urandom(16).hex()  # genuinely unknown to anyone -- SQLi is the only way in
conn.execute("INSERT INTO staff (id, username, password) VALUES (1, 'admin', ?)", (admin_pw,))
conn.commit()
conn.close()
print("Portal DB seeded.")
