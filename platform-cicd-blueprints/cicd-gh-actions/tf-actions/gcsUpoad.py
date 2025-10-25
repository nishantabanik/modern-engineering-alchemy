from gcloud import storage
storage_client = storage.Client()
bucket = storage_client.get_bucket("tf-actions-bucket-012")
blob = bucket.blob('actionsfolder/newtxt.txt')
blob.upload_from_filename('./test.txt')
