from flask import Flask, jsonify
import datetime, socket

app = Flask(__name__)

@app.route('/api/v1/info')
def info():
    return jsonify({
        'message': 'Hello World',
        'time': datetime.datetime.now().strftime("%I:%M%:%S%p on %B %d, %Y"),
        'hostname': socket.gethostname(),
        'message' : 'You are doing a great job, my friend!!! :)',
        'deployed_on': 'kubernetes'
        })

@app.route('/api/v1/healthz')

def health():
    return jsonify({
        'status': 'It is UP inside Kubernetes',
        'time': datetime.datetime.now().strftime("%I:%M%:%S%p on %B %d, %Y"),
        'hostname': socket.gethostname(),
        'message' : 'TODAY is going to be an AWESOME, my friend!!'
        })

if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0")
