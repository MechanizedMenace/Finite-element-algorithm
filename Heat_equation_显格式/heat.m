function u = heat(node,elem,pde)
%%
%求解一个heat方程的有限元程序
dt = 0.0001;
t = 0:0.0001:1;

% r=dt/dh^2 < 1/2; 满足显格式收敛条件
%
%  使用元胞数组来存储不同时间处的数值解U{0+dt}
u{1} = pde.u0(node);
for t_idx = 2:size(t,2)
    N = size(node,1);  NT = size(elem,1); 
    Ndof = N;

    %计算局部梯度算子
    [Dphi,area] = gradbasis(node,elem);

    %计算高斯积分点(阶为3)
    [lambda,weight] = quadpts(3);  
    phi = lambda;
    nQuad = size(lambda,1);
    
    %组装刚度矩阵A
    A = sparse(Ndof,Ndof);
    M = sparse(Ndof,Ndof);
    for i = 1:3
        for j = i:3
            % 计算a(u,v) 
            Aij = (Dphi(:,1,i).*Dphi(:,1,j) + Dphi(:,2,i).*Dphi(:,2,j)).*area;
        
            % 计算(u,v)
            Mij = zeros(NT,1);
            for p = 1:nQuad
                Mij = Mij + weight(p) * phi(p,i) * phi(p,j) .* area;
            end
            
            if (j==i)
                A = A + sparse(elem(:,i),elem(:,j),Aij,Ndof,Ndof);
                M = M + sparse(elem(:,i),elem(:,j),Mij,Ndof,Ndof);
            else
                A = A + sparse([elem(:,i);elem(:,j)],[elem(:,j);elem(:,i)],...
                           [Aij; Aij],Ndof,Ndof); 
                M = M + sparse([elem(:,i);elem(:,j)],[elem(:,j);elem(:,i)],...
                           [Mij; Mij],Ndof,Ndof);
            end
        end
    end
    clear K Aij Mij
    
    %% 组装右端项b
    b = zeros(Ndof,1);
    [lambda,weight] = quadpts(3);  %参见quadpts.html
    phi = lambda;
    nQuad = size(lambda,1);
    bt = zeros(NT,3);
    for p = 1:nQuad
        pxy = lambda(p,1)*node(elem(:,1),:) ...
            + lambda(p,2)*node(elem(:,2),:) ...
            + lambda(p,3)*node(elem(:,3),:);
        fp = pde.f(pxy,t(t_idx));
        for i = 1:3
            bt(:,i) = bt(:,i) + weight(p)*phi(p,i)*fp;
        end
    end
    bt = bt.*repmat(area,1,3);
    b = accumarray(elem(:),bt(:),[Ndof 1]);
    clear pxy bt
    
    %% 边界条件的处理(Dirichlet边界条件)(移到右端项,并对b进行修改)
    u{t_idx} = zeros(Ndof,1);
    fixedNode = []; %边界点 
    freeNode = [];  %内部点
    [fixedNode,bdEdge,isBdNode] = findboundary(elem);
    freeNode = find(~isBdNode);

    %MD(fixedNode,fixedNode)=I, MD(fixedNode,freeNode)=0, 
    %MD(freeNode,fixedNode)=0
    if ~isempty(fixedNode)
        bdidx = zeros(Ndof,1); 
        bdidx(fixedNode) = 1;
        Tbd = spdiags(bdidx,0,Ndof,Ndof);
        T = spdiags(1-bdidx,0,Ndof,Ndof);
        MD = T*M*T + Tbd;
    end
    
    %% 修改右端项b
    u{t_idx}(fixedNode) = pde.g_D(node(fixedNode,:),t(t_idx));
    b = (M - A * dt) * u{t_idx-1} + b * dt - M * u{t_idx};
    %
    %求解线性方程组
    u{t_idx}(freeNode) = MD(freeNode,freeNode)\b(freeNode);
end  %end t

end %end function