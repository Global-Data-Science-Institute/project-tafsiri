# Luhya Language Dataset

This directory contains the comprehensive Luhya multilingual dataset used for training translation models.

## Dataset Structure

```
data/
├── raw/                    # Source data from various origins
│   ├── bible/             # Biblical translations
│   ├── dictionary/        # Dictionary entries
│   ├── proverbs/          # Traditional proverbs
│   └── community_contributions/  # Modern usage examples
├── processed/             # Cleaned and formatted data
│   ├── train.csv         # Training split (80%)
│   ├── val.csv           # Validation split (10%) 
│   └── test.csv          # Test split (10%)
└── metadata/             # Dataset metadata and documentation
    ├── dialects.json     # Dialect information
    ├── speakers.json     # Speaker demographics
    └── cultural_context.json  # Cultural metadata
```

## Data Sources

### Biblical Texts (3,996 pairs)
- Traditional Luhya Bible translations
- Cross-referenced with English versions
- Covers multiple dialects
- Culturally significant religious language

### Dictionary Entries (7,674 pairs)
- Comprehensive vocabulary across dialects
- Word definitions and usage examples
- Traditional and modern terminology
- Cross-dialect equivalents

### Proverbs (1,122 pairs)
- Traditional Luhya wisdom sayings
- Cultural context preservation
- Metaphorical language patterns
- Cross-cultural understanding

### Community Contributions (15,162 pairs)
- Modern usage patterns
- Conversational language
- Contemporary terminology
- Community-validated translations

## Data Format

Each dataset file contains:
```csv
source_text,target_text,source_lang,target_lang,dialect,domain
"Hello, how are you?","<luy_bukusu> Murachi mulahi?","en","luy","Bukusu","greetings"
```

### Fields
- `source_text`: Original text for translation
- `target_text`: Translation with dialect token
- `source_lang`: Source language code (en, sw, luy)
- `target_lang`: Target language code
- `dialect`: Specific Luhya dialect
- `domain`: Content domain (bible, dictionary, proverbs, etc.)

## Quality Assurance

All data undergoes rigorous quality control:
1. **Native speaker validation** for accuracy
2. **Cultural appropriateness** review
3. **Dialect consistency** checking
4. **Community approval** process

## Usage Guidelines

When using this dataset:
- Respect the cultural origin of traditional content
- Acknowledge community contributions
- Maintain attribution to source communities
- Use for language preservation and empowerment

## Statistics

| Split | Examples | Coverage |
|-------|----------|----------|
| Train | 20,961   | 80%      |
| Val   | 2,620    | 10%      |
| Test  | 2,621    | 10%      |
| **Total** | **26,202** | **100%** |

### Dialect Distribution
- Bukusu: 35% of examples
- Wanga: 28% of examples
- Maragoli: 20% of examples
- Others: 17% of examples

## Citing This Dataset

```bibtex
@dataset{luhya_multilingual_2024,
  title={Luhya Multilingual Translation Dataset},
  author={[YOUR_NAME]},
  year={2024},
  url={https://huggingface.co/datasets/mamakobe/luhya-multilingual-dataset},
  note={Community-sourced Luhya language translations}
}
```
