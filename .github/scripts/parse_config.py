import os, sys, yaml, json

config_file = sys.argv[1]
config_dir = os.path.dirname(config_file)

with open(config_file) as f:
    config = yaml.safe_load(f)

image = config.get('image', '')
if not image:
    print('NO_IMAGE')
    sys.exit(0)

image_name = image.split('/')[-1].replace('{arch}-', '')
registry_prefix = '/'.join(image.split('/')[:-1])
version = str(config.get('version', 'latest')).strip("'\"")
archs = config.get('arch', [])

# Read build.yaml to get build_from mapping
build_from = {}
build_file = os.path.join(config_dir, 'build.yaml')
if os.path.exists(build_file):
    with open(build_file) as f:
        build_config = yaml.safe_load(f)
    build_from = build_config.get('build_from', {})

print(json.dumps({
    'image_name': image_name,
    'registry_prefix': registry_prefix,
    'version': version,
    'archs': archs,
    'build_from': build_from
}))
