FROM pypy:3-slim

WORKDIR /usr/src/carlito

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY ./src .

CMD [ "pypy3", "./bot.py" ]