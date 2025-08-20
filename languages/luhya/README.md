# LuhyaAI - Luhya Language Implementation

LuhyaAI is the foundational implementation of Project Tafsiri, focusing on the Luhya language cluster spoken by over 6 million people across Kenya, Uganda, and Tanzania.

## Overview

Luhya represents multiple related dialects with rich cultural traditions. Our implementation supports:

### Supported Dialects
- **Bukusu** (luy_bukusu) - ~2M speakers
- **Wanga** (luy_wanga) - ~1.5M speakers  
- **Maragoli** (luy_maragoli) - ~1M speakers
- **Kisa** (luy_kisa) - ~500K speakers
- **Tachoni** (luy_tachoni) - ~400K speakers
- **Kabras** (luy_kabras) - ~300K speakers

## Dataset

Our training dataset includes 26,000+ translation pairs from:
- **Biblical texts** - Traditional religious translations
- **Dictionary entries** - Comprehensive vocabulary
- **Proverbs and sayings** - Cultural wisdom
- **Community contributions** - Modern usage patterns

## Models

### Translation Model
- **Base**: Facebook M2M100 (418M parameters)
- **Fine-tuning**: 8 epochs with cultural context integration
- **Evaluation**: BLEU scores and cultural accuracy metrics
- **HuggingFace**: Available at `[USERNAME]/luhya-multilingual-m2m100`

### Performance
| Dialect | BLEU Score | Cultural Accuracy |
|---------|------------|------------------|
| Bukusu  | 0.xx       | xx%              |
| Wanga   | 0.xx       | xx%              |
| Maragoli| 0.xx       | xx%              |

## Usage

### Local Translation
```python
from languages.luhya.models.translation import LuhyaTranslator

translator = LuhyaTranslator()
result = translator.translate(
    text="Good morning, my friend",
    source_lang="en",
    target_dialect="luy_bukusu"
)
print(result)  # <luy_bukusu> Mulahi kweruxa, mukali wanje
```

### Training Scripts
The `scripts/` directory contains Kaggle notebook code adapted for local use:
- `data_extraction.py` - Extract and preprocess data from Supabase
- `train_translation_model.py` - Enhanced training with visual testing
- `huggingface_integration.py` - Automatic checkpoint and model upload
- `evaluation.py` - Comprehensive model evaluation

## Cultural Context

LuhyaAI incorporates cultural understanding through:
- **Traditional greetings** and social conventions
- **Proverb translations** that preserve meaning
- **Age and respect hierarchies** in language use
- **Cultural metaphors** and expressions

## Community Involvement

This implementation was developed with input from:
- Native Luhya speakers from all dialect communities
- Cultural experts and traditional knowledge keepers
- Academic linguists specializing in Bantu languages
- Technology advocates from Luhya communities

## Evaluation & Testing

We use multiple evaluation methods:
- **Automatic metrics**: BLEU, METEOR, cultural context scores
- **Human evaluation**: Native speaker validation
- **Cultural accuracy**: Community expert review
- **Cross-dialect consistency**: Translation quality across dialects

## Future Enhancements

- Enhanced chatbot with cultural context awareness
- Voice recognition and text-to-speech
- Educational applications for language learning
- Cultural content preservation tools

## Contributing

To contribute to LuhyaAI:
1. Review our [Cultural Guidelines](../../docs/cultural_guidelines.md)
2. Connect with Luhya language communities
3. Validate translations with native speakers
4. Respect traditional knowledge and cultural practices

---

LuhyaAI - Preserving and empowering Luhya languages in the digital age.
