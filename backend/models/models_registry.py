from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
import logging

logger = logging.getLogger(__name__)


def get_tokenizer(model_name):
    _tokenizer = AutoTokenizer.from_pretrained(model_name)
    return _tokenizer


def get_model(model_name):
    _model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    return _model


MODEL_REGISTRY = {}

SUPPORTED_MODELS = [
    "facebook/mbart-large-50-many-to-many-mmt",
    "facebook/m2m100_1.2B",
]

def load_models():
    for model_name in SUPPORTED_MODELS:
        logger.info(f"Loading model: {model_name}\n")
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
        MODEL_REGISTRY[model_name] = {"tokenizer": tokenizer, "model": model}
    logger.info("All models loaded successfully.")
    return MODEL_REGISTRY
