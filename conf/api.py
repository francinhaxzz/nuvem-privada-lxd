import os
import psycopg2
from fastapi import FastAPI, Request

app = FastAPI()

#abre a conexão com o banco de dados usando credenciais das variaveis de ambiente
def conectar():
    return psycopg2.connect(
        host=os.environ["DB_HOST"], dbname="tarefas",
        user="apiuser", password=os.environ["DB_PASS"])

#Rota de monitoramento de saude da API, para saber se o servidor esta funcionando corretamente
@app.get("/api/saude")
def saude():
    return {"status": "ok"}

#Rota para listar todas as tarefas ordendas pelo ID
@app.get("/api/tarefas")
def listar():
    con = conectar()
    cur = con.cursor() #Cria o cursor para executar comandos SQL
    cur.execute("SELECT id, titulo, feita FROM tarefas ORDER BY id")
    linhas = [{"id": l[0], "titulo": l[1], "feita": l[2]} for l in cur.fetchall()]
    con.close()
    return linhas

#Rota para criar uma nova tarefa, recebendo o titulo da tarefa no corpo da requisição
@app.post("/api/tarefas")
async def criar(req: Request):
dados = await req.json() #Recebe os dados da requisição em formato JSON
    con = conectar() #Abre a conexão com o banco de dados
    cur = con.cursor() #Cria o cursor para executar comandos SQL
    cur.execute("INSERT INTO tarefas (titulo) VALUES (%s) RETURNING id", (dados["titulo"],))
    novo_id = cur.fetchone()[0] #Recupera o ID da nova tarefa criada
    con.commit()#Confirma a transação no banco de dados
    con.close() # Fecha a conexão com o banco de dados
    return {"id": novo_id}

#Rota para concluir uma tarefa existente, recebendo o ID da tarefa como parâmetro
@app.put("/api/tarefas/{tarefa_id}")
def concluir(tarefa_id: int):
    con = conectar()
    cur = con.cursor() #Cria o cursor para executar comandos SQL
    cur.execute("UPDATE tarefas SET feita = true WHERE id = %s", (tarefa_id,))
    con.commit() #Confirma a transação no banco de dados
    con.close()# Fecha a conexão com o banco de dados
    return {"id": tarefa_id, "feita": True}

#Rota para apagar uma tarefa existente, recebendo o ID da tarefa como parâmetro
@app.delete("/api/tarefas/{tarefa_id}")
def apagar(tarefa_id: int):
    con = conectar() #Abre a conexão com o banco de dados
    cur = con.cursor() #Cria o cursor para executar comandos SQL
    cur.execute("DELETE FROM tarefas WHERE id = %s", (tarefa_id,))
    con.commit() #Confirma a transação no banco de dados
    con.close() # Fecha a conexão com o banco de dados
    return {"apagada": tarefa_id}
