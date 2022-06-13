import boto3
import socket
from flask import Flask

app = Flask(__name__)
ssm = boto3.client('ssm', region_name='us-east-1')


@app.route("/")

def hello():
	parameter = ssm.get_parameter(Name='interview-parameter', WithDecryption=True)
	return "You have reached pod {0}. This pod read the SSM parameter value of: {1}".format(socket.gethostname(), parameter['Parameter']['Value'])

if __name__ == "__main__":
	app.run(host='0.0.0.0', port=8080)