from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Backend is set up and running!"

if __name__ == '__main__':
    app.run(debug=True)
