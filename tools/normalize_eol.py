from pathlib import Path

def main():
    dir = Path(__file__).parent.parent

    for file in dir.glob('**/*.cs'):
        skip = False

        for part in file.parts:
            if str(part).startswith('.'):
                skip = True
                break
        
        if skip:
            continue

        with open(file, 'r') as f:
            data = f.read()
        
        with open(file, 'w', newline='\n') as f:
            f.write(data)

if __name__ == "__main__":
    main()
