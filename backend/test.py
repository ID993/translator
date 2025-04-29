# import re
# import fasttext
# import os
# from langdetect import detect


# LOCAL_DIR = os.path.dirname(__file__)
# MODEL_PATH = os.path.join(LOCAL_DIR, "models", "lid.176.bin")

# model = fasttext.load_model(MODEL_PATH)


# def normalize(text):
#     text = text.lower()
#     text = re.sub(r"[^\w\s]", " ", text)
#     return " ".join(text.split())


# def detect_language(text: str, k: int = 1):
#     labels, probabilities = model.predict(normalize(text), k=k)
#     results = [(lbl.replace("__label__", ""), prob)
#                for lbl, prob in zip(labels, probabilities)]
#     return results


# if __name__ == "__main__":
#     examples = [
#         "I'm gonna win.",
#         "Ik ben vanmorgen eerder wakker geworden dan normaal.",
#         "Esta es una prueba de detección de idioma.",
#         "Moja sestra voli svirati klavir poslijepodne.",
#         "Vozim bicikl do posla svaki dan.",
#         "Našla sam stari album sa starim fotografijama."
#     ]
#     for sentence in examples:
#         print(sentence, "->", detect_language(sentence, k=2))
#         print(detect(sentence))
composite = "ml_:_facebook/m2m100_1.2B"
engine, model_name = composite.split('_:_')

print(engine)
print(model_name)
