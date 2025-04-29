from transformers import M2M100ForConditionalGeneration, M2M100Tokenizer
# from transformers import MBartForConditionalGeneration, MBart50TokenizerFast
# OR
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

# tokenizer = AutoTokenizer.from_pretrained("facebook/mbart-large-50-many-to-many-mmt")
# model = AutoModelForSeq2SeqLM.from_pretrained("facebook/mbart-large-50-many-to-many-mmt")

# _MODEL_NAME = "facebook/m2m100_418M"  # m2m100_1.2B
_MODEL_NAME = "facebook/m2m100_1.2B"
_tokenizer = None
_model = None


def get_tokenizer(model_name):
    global _tokenizer
    if _tokenizer is None:
        # _tokenizer = M2M100Tokenizer.from_pretrained(_MODEL_NAME)
        _tokenizer = AutoTokenizer.from_pretrained(model_name)
    return _tokenizer


def get_model(model_name):
    global _model
    if _model is None:
        # _model = M2M100ForConditionalGeneration.from_pretrained(_MODEL_NAME)
        _model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
    return _model
