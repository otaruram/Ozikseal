import os
import sys

# Add the parent directory (backend root) to sys.path so it can find main.py and fpga_serial.py
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mangum import Mangum
from main import app

# This handler is what Netlify/AWS Lambda will execute
handler = Mangum(app)
