from google import genai
from google.genai import types
import sys
import os

api_key = os.environ['GOOGLE_AI_API_KEY']
client = genai.Client(api_key=api_key)

response = client.models.generate_images(
    model='imagen-3.0-generate-002',
    prompt=sys.argv[1],
    config=types.GenerateImagesConfig(
        number_of_images=1,
    )
)
for generated_image in response.generated_images:
  sys.stdout.buffer.write(generated_image.image.image_bytes)
