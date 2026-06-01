-- Criação da tabela "leitura_temperatura"

CREATE TABLE leitura_temperatura (
	tempo TIMESTAMPTZ NOT NULL,
	dispositivo TEXT NOT NULL,
	temperatura DOUBLE PRECISION
);

/* Transforma a tabela comum "leitura_temperatura" em uma
	hypertable, organizada por chunks de 1 dia, evidenciado
	no argumento "by_range('tempo', INTERVAL '1 day')"
*/

SELECT create_hypertable(
	'leitura_temperatura',
	by_range('tempo', INTERVAL '1 day')
);

/* Inserção dos Dados na Tabela
	a fórmula de inserção da temperatura faz com que todos os dados sejam mais fiéis
	às temperaturas reais durante o dia, mais frias de noite e mais quentes ao dia, 
	a consulta faz isso usando uma função seno para realizar a variação, dividindo o
	tempo do período da tabela inteiro pela quantidade de segundos que um dia possui.
	Além disso, é somado um ruído (random() - 0.5) à temperatura de cada linha para diferenciar uma das
	outras.
*/

INSERT INTO leitura_temperatura (tempo, dispositivo, temperatura)
SELECT
	t,
	d,
	22 + 5 * sin(extract(epoch FROM t) / 86400 * 2 * pi()) + (random() - 0.5) * 2
FROM
	generate_series(
		now() - interval '30 days',
		now(),
		interval '1 minute'
	) AS t,
	unnest(ARRAY['CLP-1', 'CLP-2', 'CLP-3']) AS d;

select * from leitura_temperatura;

/* Consulta inteira dos chunks
	Esta consulta retorna todos os dados da tabela "leitura_temperatura"
	separados pelos chunks automaticamente gerados e armazenados em 
	"timescaledb_information.chunks"
*/

SELECT
	chunk_name,
	range_start,
	range_end
FROM timescaledb_information.chunks
WHERE hypertable_name = 'leitura_temperatura'
ORDER BY range_start;

/* Consulta de análise de estatísticas
	As palavras reservadas "EXPLAIN ANALYSE" retorna métricas sobre a própria consulta
	realiza, como a velocidade de retorno dos dados consultados
*/

EXPLAIN ANALYZE
	SELECT avg(temperatura)
	FROM leitura_temperatura
WHERE tempo > now() - interval '1 day';

/* Possui o mesmo funcionamento do comando acima porém
	com uma consulta retornando todos os dados sem filtro
	(consequentemente com um tempo maior)
*/

EXPLAIN ANALYZE
	SELECT avg(temperatura)
FROM leitura_temperatura;

/* Visão Materializada
	visão materializada que retorna um time_bucket de 1 hora, totalizando
	60 registros agrupados em um, considerando que cada chunk é de 1 minuto
*/

CREATE MATERIALIZED VIEW media_horaria
	WITH (timescaledb.continuous) AS
SELECT
	time_bucket('1 hour', tempo) AS hora,
	dispositivo,
	avg(temperatura) AS temperatura_media,
	max(temperatura) AS temperatura_max,
	min(temperatura) AS temperatura_min,
	count(*) AS numero_leituras
FROM leitura_temperatura
GROUP BY hora, dispositivo;

select * from media_horaria
order by hora, dispositivo;

DROP MATERIALIZED VIEW media_horaria;



