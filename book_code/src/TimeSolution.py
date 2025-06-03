"""
Author: Eugene Asahara

This Python script, associated with the book, Time Molecules. It computes the stationary 
distribution for each Markov model stored in the SQL Server–based TimeSolution framework. 

It first connects to the database using credentials stored in a .env file, then retrieves 
the transition matrix for each model via the [dbo].[ModelMatrix](ModelID) 
table-valued function. After validating the matrix (checking for missing events or zero 
probabilities), it calculates the long-run steady-state distribution by iteratively 
multiplying the transition matrix by a probability vector until convergence. 
The resulting vector—representing the stationary distribution—is written back to the 
dbo.Model_Stationary_Distribution table for further analysis. 

This allows users to understand long-term behavior in customer journeys, workflows, 
or other modeled processes. The script loops through all existing models in the 
Models table, automatically processing each one.

"""
import pyodbc
import pandas as pd
import numpy as np
import os
from dotenv import load_dotenv
# def calc_stationary_probability(modelID:int):

# Be sure .env is in the same directory as this file.
load_dotenv()

def open_connection():
    # Connect to SQL Server
    conn = pyodbc.connect(f'DRIVER={{SQL Server}};SERVER={os.getenv("TIMESOLUTION_SERVER_NAME")};DATABASE={os.getenv("TIMESOLUTION_DATABASE_NAME")};Trusted_Connection=yes')
    return conn

def execute_query(conn, sql:str, return_value:bool=True)->pd.DataFrame:
    cursor = conn.cursor()
    cursor.execute(sql)
    if not return_value:
        return
    data = cursor.fetchall()
    return pd.DataFrame.from_records(data,columns=[col[0] for col in cursor.description])

def stationary_distribution(ModelID:int, iterations:int=15):
    conn = open_connection()
    sql = f'SELECT EventA,EventB,Prob FROM [dbo].[ModelMatrix]({ModelID})'
    df = execute_query(conn, sql)

    # Check for missing events
    event_a = df['EventA'].unique()
    event_b = df['EventB'].unique()

    # Ensure each event appears in both EventA and EventB
    missing_in_a = set(event_b) - set(event_a)
    missing_in_b = set(event_a) - set(event_b)

    if missing_in_a or missing_in_b:
        print(f"Events missing in EventA: {missing_in_a}")
        print(f"Events missing in EventB: {missing_in_b}")
        return None

    # Check for any zero probabilities
    zero_prob = df[df['Prob'] == 0]
    if not zero_prob.empty:
        print(f"Found zero probabilities in transitions: {zero_prob}")
        return None


    matrix= df.pivot(index='EventB', columns='EventA', values='Prob').fillna(0)

    matrix_len=len(matrix.columns)

    pi = [1 if i==0 else 0 for i in range(0,matrix_len)] # Create the starting vector - For example, [1,0,0,0]
    prev_pi = np.zeros_like(pi)
    for i in range(0, iterations):
        pi = np.dot(matrix, pi)
        if np.allclose(pi, prev_pi, atol=1e-6):
            break
        prev_pi = pi

    print(pi)
    sql = f"DELETE FROM dbo.Model_Stationary_Distribution WHERE ModelID={ModelID};"
    for i in range(0,len(matrix.columns)):
        sql += f"INSERT INTO dbo.Model_Stationary_Distribution (ModelID, [Event],Probability) VALUES ({ModelID}, '{matrix.columns[i]}',{pi[i]});"
    execute_query(conn,sql, return_value=False)
    conn.commit()
    print(f"Stationary distribution calculated for ModelID: {ModelID}")
    # Close the connection
    conn.close()

if __name__ == "__main__":

    conn = open_connection()
    sql = f'TRUNCATE TABLE dbo.Model_Stationary_Distribution'
    df = execute_query(conn, sql,False)
    conn.close()

    conn = open_connection()
    sql = f'SELECT DISTINCT ModelID FROM Models'
    df = execute_query(conn, sql)
    conn.close()

    for modelId in df['ModelID']:
        print(f"Calculating stationary distribution for ModelID: {modelId}")
        stationary_distribution(modelId)