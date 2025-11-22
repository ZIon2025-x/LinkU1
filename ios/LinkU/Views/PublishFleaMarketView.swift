//
//  PublishFleaMarketView.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI

struct PublishFleaMarketView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PublishFleaMarketViewModel()
    @State private var title = ""
    @State private var description = ""
    @State private var category = "Electronics"
    @State private var location = "London"
    @State private var price: Double = 0
    @State private var contact = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    
    let categories = ["Electronics", "Furniture", "Clothing", "Books", "Sports", "Other"]
    let cities = ["Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", 
                  "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", 
                  "Southampton", "Liverpool", "Cardiff", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("商品信息") {
                    TextField("商品标题", text: $title)
                    TextEditor(text: $description)
                        .frame(height: 100)
                    
                    Picker("分类", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    Picker("城市", selection: $location) {
                        ForEach(cities, id: \.self) { city in
                            Text(city).tag(city)
                        }
                    }
                }
                
                Section("价格") {
                    HStack {
                        Text("£")
                        TextField("0.00", value: $price, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("联系方式") {
                    TextField("联系方式（可选）", text: $contact)
                }
                
                Section("图片（最多5张）") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(selectedImages.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Button(action: {
                                        selectedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white.clipShape(Circle()))
                                    }
                                }
                            }
                            
                            if selectedImages.count < 5 {
                                Button(action: {
                                    showImagePicker = true
                                }) {
                                    VStack {
                                        Image(systemName: "plus")
                                            .font(.title2)
                                        Text("添加图片")
                                            .font(.caption)
                                    }
                                    .frame(width: 100, height: 100)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("发布商品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("发布") {
                        publishItem()
                    }
                    .disabled(viewModel.isLoading || title.isEmpty || description.isEmpty || price <= 0)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: Binding(
                    get: { nil },
                    set: { image in
                        if let image = image, selectedImages.count < 5 {
                            selectedImages.append(image)
                        }
                    }
                ))
            }
        }
    }
    
    private func publishItem() {
        viewModel.publishItem(
            title: title,
            description: description,
            category: category,
            location: location,
            price: price,
            contact: contact,
            images: selectedImages
        ) { success in
            if success {
                dismiss()
            }
        }
    }
}

class PublishFleaMarketViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func publishItem(
        title: String,
        description: String,
        category: String,
        location: String,
        price: Double,
        contact: String,
        images: [UIImage],
        completion: @escaping (Bool) -> Void
    ) {
        isLoading = true
        errorMessage = nil
        
        // TODO: 实现发布跳蚤市场商品的API
        // 先上传图片，然后创建商品
        completion(true)
    }
}

#Preview {
    PublishFleaMarketView()
}

