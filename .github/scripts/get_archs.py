import sys, yaml

config_file = sys.argv[1]
with open(config_file) as f:
    config = yaml.safe_load(f)

for a in config.get('arch', []):
    print(a)
