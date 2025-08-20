# Project Tafsiri

**Bridging African Languages and Modern AI Technology**

Project Tafsiri (Swahili for "translation") is an open-source initiative to create comprehensive, culturally-aware AI systems for African languages. We're building translation models, chatbots, and language tools that understand cultural context, preserve traditional knowledge, and empower communities to access modern technology without abandoning their linguistic heritage.

## Vision

The vision of Project Tafsiri extends beyond simple translation. We are creating AI systems that:
- **Understand cultural context** and linguistic nuances
- **Preserve traditional knowledge** embedded in oral traditions
- **Empower communities** to engage with technology in their native languages
- **Maintain cultural authenticity** through community involvement
- **Support linguistic diversity** across the African continent

## Current Status: LuhyaAI

We're starting with **Luhya**, a Bantu language cluster spoken by over 6 million people across Kenya, Uganda, and Tanzania. Luhya provides an ideal foundation with:

- **Significant speaker population** (6+ million native speakers)
- **Rich dialect diversity** (Bukusu, Maragoli, Wanga, Tsotso, Kisa, and others)
- **Cultural richness** with extensive oral traditions and proverbs
- **Community engagement** ensuring linguistic and cultural accuracy

### Supported Luhya Dialects
- Bukusu (luy_bukusu)
- Wanga (luy_wanga)
- Kisa (luy_kisa)
- Maragoli (luy_maragoli)
- Tachoni (luy_tachoni)
- Kabras (luy_kabras)

## Resources

### HuggingFace Hub
- **Dataset**: [luhya-multilingual-dataset](https://huggingface.co/datasets/mamakobe/luhya-multilingual-dataset) - 26K+ translation pairs
- **Model**: [luhya-multilingual-m2m100](https://huggingface.co/mamakobe/luhya-multilingual-m2m100) - Fine-tuned M2M100 model
- **Checkpoints**: Private repository for training checkpoints

### Research & Development
- Translation model based on Facebook's M2M100
- Cultural context integration
- Dialect-specific adaptations
- Community validation framework

## Quick Start

### Installation
```bash
git clone https://github.com/Global-Data-Science-Institute/project-tafsiri.git
cd project-tafsiri
pip install -r requirements/base.txt
```

### Basic Translation
```python
from transformers import M2M100ForConditionalGeneration, M2M100Tokenizer

# Load the model
model = M2M100ForConditionalGeneration.from_pretrained("mamakobe/luhya-multilingual-m2m100")
tokenizer = M2M100Tokenizer.from_pretrained("mamakobe/luhya-multilingual-m2m100")

# Translate English to Bukusu
text = "Hello, how are you?"
inputs = tokenizer(text, return_tensors="pt")
outputs = model.generate(**inputs, forced_bos_token_id=tokenizer.convert_tokens_to_ids("<luy_bukusu>"))
translation = tokenizer.decode(outputs[0], skip_special_tokens=True)
print(translation)  # <luy_bukusu> Murachi mulahi?
```

### API Usage
```bash
# Start the translation API
cd api/translation_api
uvicorn app:app --reload

# Translate via API
curl -X POST "http://localhost:8000/translate" \
  -H "Content-Type: application/json" \
  -d '{"text": "Good morning", "source_lang": "en", "target_dialect": "luy_bukusu"}'
```

## Project Structure

```
project-tafsiri/
├── languages/           # Language-specific implementations
│   ├── luhya/          # Primary Luhya implementation
│   ├── swahili/        # Future: Swahili support
│   └── template/       # Template for new languages
├── core/               # Shared infrastructure
├── tools/              # Development and deployment tools
├── api/                # REST API and web services
├── community/          # Community engagement
├── research/           # Academic research and benchmarks
└── examples/           # Usage examples and demos
```

## Contributing

We welcome contributions from developers, linguists, cultural experts, and community members. See our [Contributing Guidelines](CONTRIBUTING.md) and [Cultural Guidelines](docs/cultural_guidelines.md).

### How to Contribute
1. **Code contributions**: Improve models, add features, fix bugs
2. **Language expertise**: Validate translations, provide cultural context
3. **Community outreach**: Help connect with language communities
4. **Research**: Contribute to academic research and benchmarks
5. **Documentation**: Improve guides and examples

## Community

Project Tafsiri is built with and for African language communities. We prioritize:
- **Community involvement** in all development decisions
- **Cultural authenticity** over technical convenience  
- **Respectful engagement** with traditional knowledge
- **Transparent development** with open-source principles

### Get Involved
- Join our [discussions](https://github.com/Global-Data-Science-Institute/project-tafsiri/discussions)
- Follow development on [GitHub](https://github.com/Global-Data-Science-Institute/project-tafsiri)
- Connect with us on social media
- Attend community workshops and presentations

## Roadmap

### Phase 1: Luhya Foundation (Current)
- ✅ Multi-dialect Luhya translation model
- ✅ Cultural context integration
- ✅ Community validation framework
- 🔄 Enhanced chatbot capabilities
- 🔄 Mobile application development

### Phase 2: Expansion (2024-2025)
- Swahili integration and cross-language translation
- Yoruba language implementation
- Advanced cultural context understanding
- Educational tool development

### Phase 3: Pan-African (2025+)
- Additional East African languages
- West African language cluster
- Southern African language support
- Continental language exchange platform

## Academic & Research

Project Tafsiri welcomes academic collaboration and research partnerships. Our work contributes to:
- Low-resource language AI research
- Cultural context in machine translation
- Community-driven AI development
- African language preservation technology

See our [Research section](research/) for papers, benchmarks, and academic resources.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Citation

If you use Project Tafsiri in your research or applications, please cite:

```bibtex
@software{project_tafsiri_2024,
  title={Project Tafsiri: African Language AI Systems},
  author={[YOUR_NAME]},
  year={2024},
  url={https://github.com/Global-Data-Science-Institute/project-tafsiri},
  note={Open-source African language translation and AI tools}
}
```

## Acknowledgments

- Luhya language communities for cultural guidance and validation
- Facebook AI Research for the M2M100 base model
- HuggingFace for model hosting and community platform
- All contributors and community members

---

**Project Tafsiri** - *Empowering African voices in the digital age*
