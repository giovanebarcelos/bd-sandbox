# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) · versões: [SemVer](https://semver.org/lang/pt-BR/).

## [1.0.0] — entrega da A3

### Adicionado
- Modelo de 8 tabelas (DER em PlantUML e Mermaid), DDL e dados de exemplo para PostgreSQL 17 e Oracle XE 21
- 10 consultas analíticas (JOIN, window function, agregação, anti-join, divisão relacional, ROLLUP) com resultado idêntico nos dois bancos
- Procedures `registrar_entrada_lote` e `consumir_insumo` (FEFO) e triggers de validação e de auditoria, em PL/pgSQL e PL/SQL
- Três índices e medição antes/depois (`performance/medir.py`)
- Aplicações Python (psycopg, oracledb) e Java (JDBC) com os mesmos roteiros
- 152 testes pytest (76 cenários × 2 bancos), 23 mutantes dos scripts SQL e `docker-compose.yml`

### Corrigido
- `consumir_insumo` reportava sucesso ao atender só parte do pedido quando outro operador consumia o mesmo lote ao mesmo tempo
