
resource "local_file" "pet_name" {
	    content = "We love pets!"
	    filename = "/root/pets.txt"
}


resource "random_pet" "my-pet" {
	      prefix = "Mrs"
	      separator = "."
	      length = "1"
}