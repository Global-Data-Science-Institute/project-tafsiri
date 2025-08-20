#!/usr/bin/env python3
"""
Basic Project Tafsiri Translation Example

This example shows how to use the Luhya translation model
for basic text translation between English and Luhya dialects.
"""

from transformers import M2M100ForConditionalGeneration, M2M100Tokenizer
import torch

def main():
    # Load the trained Luhya model
    model_name = "mamakobe/luhya-multilingual-m2m100"
    
    print("Loading Luhya translation model...")
    model = M2M100ForConditionalGeneration.from_pretrained(model_name)
    tokenizer = M2M100Tokenizer.from_pretrained(model_name)
    
    # Set device
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)
    
    # Example translations
    examples = [
        ("Hello, how are you?", "luy_bukusu"),
        ("Good morning", "luy_wanga"),
        ("Thank you very much", "luy_maragoli"),
        ("What is your name?", "luy_kisa"),
        ("See you tomorrow", "luy_tachoni")
    ]
    
    print("\nTranslation Examples:")
    print("-" * 50)
    
    for text, dialect in examples:
        translation = translate_text(text, dialect, model, tokenizer, device)
        print(f"EN: {text}")
        print(f"{dialect.upper()}: {translation}")
        print()

def translate_text(text, target_dialect, model, tokenizer, device):
    """Translate text to specified Luhya dialect"""
    
    # Set language codes
    tokenizer.src_lang = "en"
    tokenizer.tgt_lang = "sw"  # Use Swahili as base target
    
    # Tokenize input
    inputs = tokenizer(text, return_tensors="pt", padding=True).to(device)
    
    # Get dialect token ID
    dialect_token = f"<{target_dialect}>"
    dialect_token_id = tokenizer.convert_tokens_to_ids(dialect_token)
    
    # Generate translation
    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            max_length=128,
            num_beams=5,
            early_stopping=True,
            forced_bos_token_id=dialect_token_id,
            pad_token_id=tokenizer.pad_token_id
        )
    
    # Decode and clean result
    translation = tokenizer.decode(outputs[0], skip_special_tokens=False)
    translation = translation.replace('<s>', '').replace('</s>', '').strip()
    
    return translation

if __name__ == "__main__":
    main()
