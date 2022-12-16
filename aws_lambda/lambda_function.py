import psycopg2
from psycopg2.extras import RealDictCursor


def lambda_handler(event, context):
    host = event['host']
    username = event['username']
    password = event['password']
    dbname = event['dbname']
    conn = psycopg2.connect(host = host, database = dbname,user = username,password = password)
    print('Please wait while the program is loading...')
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    conn.set_session(autocommit=True)
    cursor.execute('CALL prom_api.execute_maintenance()')
    cursor.close()
    conn.close()
    print("Procedure completed")

lambda_handler()
