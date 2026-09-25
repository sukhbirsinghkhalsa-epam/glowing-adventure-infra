resource "azurerm_resource_group" "temp"{
    name = "test1"
    location = "centralindia"

}

provider "azurerm"{
    features{}
}
