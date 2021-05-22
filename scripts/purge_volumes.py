#!/usr/bin/env python3

import argparse

import openstack

parser = argparse.ArgumentParser()
cloud = openstack.connect(options=parser)

volumes = [v for v in cloud.list_volumes() if v.name.startswith('tempest-')]
for v in volumes:
    print("Deleting %s (%s)" % (v.name, v.id))

    try:
        cloud.delete_volume(v)
    except Exception as e:
        print("Failed to delete, skipping: %s" % e)