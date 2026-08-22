import os

from flask import Flask, render_template

app = Flask(__name__)

# URL the "Start AI Attendance" buttons link to. Defaults to the deployed
# Streamlit app so production behavior is unchanged. Override locally with:
#   export STREAMLIT_APP_URL=http://localhost:8501
STREAMLIT_APP_URL = os.environ.get('STREAMLIT_APP_URL', 'https://snapclass.streamlit.app/')

@app.route('/')
def home():
    return render_template('index.html', streamlit_url=STREAMLIT_APP_URL)

if __name__ == '__main__':
    app.run(debug=True, port=5002)
